class ChatController < ApplicationController
  def index
    @miembros_chat = tenant_members

    @con_id = params[:con].presence&.to_i

    if @con_id
      @destinatario = User.find_by(id: @con_id)
      return redirect_to chat_path unless @destinatario && @miembros_chat.map(&:id).include?(@con_id)

      @canal    = "dm"
      @mensajes = ChatMensaje.dm_entre(current_user.id, @con_id)
                             .includes(:user).order(:created_at).last(60)
      @stream   = "chat_dm_#{[current_user.id, @con_id].sort.join('_')}"

    elsif params[:canal] == "logia"
      @canal    = "logia"
      @mensajes = ChatMensaje.where(logia: current_logia, canal: "logia")
                             .includes(:user).order(:created_at).last(60)
      @stream   = "chat_logia_#{current_logia.id}"

    else
      @canal    = "tenant"
      root_id   = tenant_root_id
      @mensajes = ChatMensaje.where(logia_id: root_id, canal: "tenant")
                             .includes(:user).order(:created_at).last(60)
      @stream   = "chat_tenant_#{root_id}"
    end
  end

  def create
    con_id = params[:con].presence&.to_i
    canal  = params[:canal].presence

    mensaje = if con_id
      destinatario = User.find_by(id: con_id)
      return head :unprocessable_entity unless destinatario

      ChatMensaje.new(
        logia:        current_logia,
        user:         current_user,
        contenido:    params[:contenido].to_s.strip,
        canal:        "dm",
        destinatario: destinatario
      )
    elsif canal == "logia"
      ChatMensaje.new(
        logia:     current_logia,
        user:      current_user,
        contenido: params[:contenido].to_s.strip,
        canal:     "logia"
      )
    else
      root_logia = Logia.find(tenant_root_id)
      ChatMensaje.new(
        logia:     root_logia,
        user:      current_user,
        contenido: params[:contenido].to_s.strip,
        canal:     "tenant"
      )
    end

    mensaje.save!
    head :ok
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def tenant_root_id
    current_logia.tenant_id || current_logia.id
  end

  def tenant_members
    User
      .joins(:miembro)
      .where(miembros: { logia_id: logia_ids_del_tenant })
      .where.not(id: current_user.id)
      .includes(miembro: :logia)
      .order(:apellido, :nombre)
  end

  def logia_ids_del_tenant
    logia = current_logia
    ids   = [logia.id]
    ids  += logia.logias.pluck(:id) if logia.tenant_id.nil?
    ids
  end
end
