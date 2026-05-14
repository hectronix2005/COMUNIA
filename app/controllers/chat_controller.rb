class ChatController < ApplicationController
  def index
    current_user.touch_last_seen!
    @miembros_chat = tenant_members
    @dm_recientes  = dm_recientes_users

    @con_id = params[:con].presence&.to_i

    # Last message preview + unread counts for sidebar
    @ultimo_dm      = ChatMensaje.ultimo_mensaje_dm(current_user.id)
    @unread_counts  = ChatMensaje.unread_dm_for(current_user.id).group(:user_id).count

    if @con_id
      @destinatario = User.find_by(id: @con_id)
      return redirect_to chat_path unless @destinatario && @miembros_chat.map(&:id).include?(@con_id)

      @canal    = "dm"
      @mensajes = ChatMensaje.dm_entre(current_user.id, @con_id)
                             .includes(:user).order(:created_at).last(100)
      @stream   = "chat_dm_#{[current_user.id, @con_id].sort.join('_')}"

      # Mark as read
      ChatMensaje.unread_dm_for(current_user.id)
                 .where(user_id: @con_id)
                 .update_all(leido_at: Time.current)

    elsif params[:canal] == "logia"
      @canal    = "logia"
      @mensajes = ChatMensaje.where(logia: current_logia, canal: "logia")
                             .includes(:user).order(:created_at).last(100)
      @stream   = "chat_logia_#{current_logia.id}"

    else
      @canal    = "tenant"
      root_id   = tenant_root_id
      @mensajes = ChatMensaje.where(logia_id: root_id, canal: "tenant")
                             .includes(:user).order(:created_at).last(100)
      @stream   = "chat_tenant_#{root_id}"
    end
  end

  def create
    current_user.touch_last_seen!
    con_id = params[:con].presence&.to_i
    canal  = params[:canal].presence

    mensaje = if con_id
      destinatario = User.find_by(id: con_id)
      return head :forbidden unless destinatario && tenant_members.exists?(id: con_id)

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

  def marcar_leido
    mensaje = ChatMensaje.find(params[:id])
    mensaje.marcar_leido!(current_user)
    head :ok
  end

  def reaccionar
    mensaje = ChatMensaje.find(params[:id])
    emoji = params[:emoji].to_s
    return head(:unprocessable_entity) unless ChatMensaje::REACCIONES_PERMITIDAS.include?(emoji)
    mensaje.toggle_reaccion!(current_user, emoji)
    head :ok
  end

  def buscar
    query = params[:q].to_s.strip
    return render(plain: "", status: :ok) if query.length < 2

    base = case params[:canal]
    when "dm"
      ChatMensaje.dm_entre(current_user.id, params[:con].to_i)
    when "logia"
      ChatMensaje.where(logia: current_logia, canal: "logia")
    else
      ChatMensaje.where(logia_id: tenant_root_id, canal: "tenant")
    end

    @resultados = base.where("contenido ILIKE ?", "%#{ChatMensaje.sanitize_sql_like(query)}%")
                      .includes(:user).order(created_at: :desc).limit(20)
    render partial: "chat/search_results", locals: { resultados: @resultados }
  end

  def typing
    stream = params[:stream]
    return head(:forbidden) unless stream.present?
    Turbo::StreamsChannel.broadcast_append_to(
      stream,
      target: "chat-typing",
      html: "<div class='typing-indicator' data-controller='typing-remove'>
               <span class='text-muted small ps-2'><em>#{ERB::Util.html_escape(current_user.nombre_chat)} está escribiendo…</em></span>
             </div>".html_safe
    )
    head :ok
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

  def dm_recientes_users
    partner_ids = ChatMensaje.where(canal: "dm")
      .where("user_id = :uid OR destinatario_id = :uid", uid: current_user.id)
      .select("DISTINCT CASE WHEN user_id = #{current_user.id} THEN destinatario_id ELSE user_id END AS partner_id")
      .map(&:partner_id)

    return [] if partner_ids.empty?

    tenant_member_ids = @miembros_chat.map(&:id)
    valid_ids = partner_ids & tenant_member_ids

    User.where(id: valid_ids)
        .includes(miembro: :logia)
        .order(:apellido, :nombre)
  end
end
