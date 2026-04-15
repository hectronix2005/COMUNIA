class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_name = params[:stream]
    return reject unless stream_valido?(stream_name)
    stream_from stream_name
  end

  private

  def stream_valido?(stream_name)
    return false if stream_name.blank?

    if stream_name.start_with?("chat_logia_")
      logia_id = stream_name.split("_").last.to_i
      logia_ids_accesibles.include?(logia_id)

    elsif stream_name.start_with?("chat_tenant_")
      root_id          = stream_name.split("_").last.to_i
      user_logia       = current_user.logia
      return false unless user_logia
      user_tenant_root = user_logia.tenant_id || user_logia.id
      user_tenant_root == root_id

    elsif stream_name.start_with?("chat_dm_")
      ids = stream_name.sub("chat_dm_", "").split("_").map(&:to_i)
      ids.include?(current_user.id)

    else
      false
    end
  end

  def logia_ids_accesibles
    logia = current_user.logia
    return [] unless logia
    [logia.id] + (logia.tenant_id.nil? ? logia.logias.pluck(:id) : [])
  end
end
