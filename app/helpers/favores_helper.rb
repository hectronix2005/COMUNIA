module FavoresHelper
  # Lo último que piden y ofrecen los demás en la comunidad, para la tarjeta del panel.
  def favores_del_panel(limite = 3)
    Favor.de_logias(current_logia.ids_de_la_organizacion).vigentes.where.not(user: current_user)
         .includes(:user).order(Arel.sql("CASE favores.tipo WHEN 'pido' THEN 0 ELSE 1 END"), created_at: :desc).limit(limite)
  end
end
