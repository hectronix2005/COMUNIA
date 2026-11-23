-- Vuelta de devise_invitable 3.x a 2.x (la ejecuta rollback.sh antes de arrancar la versión anterior).
-- La 3.x guarda las invitaciones en devise_invitations y no toca las columnas viejas de users, que la 2.x sigue
-- leyendo: sin esto, quien aceptó, fue reinvitado o anulado con la 3.x conservaría en users su token viejo, la 2.x
-- no lo dejaría entrar y ese enlace viejo volvería a valer. Se cierra en users lo que la 3.x ya cerró y se copia la
-- fecha de aceptación; lo que sigue pendiente en las dos versiones conserva su enlace. Repetirlo no cambia nada.
-- Lo que no tiene arreglo: un enlace generado con la 3.x no sirve en la 2.x (hay que generarlo otra vez).
UPDATE users u
SET invitation_token = NULL,
    invitation_accepted_at = COALESCE(u.invitation_accepted_at, d.aceptada)
FROM (SELECT invitable_id, MAX(invitation_accepted_at) AS aceptada
      FROM devise_invitations WHERE invitable_type = 'User' GROUP BY invitable_id) d
WHERE d.invitable_id = u.id
  AND u.invitation_token IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM devise_invitations p
    WHERE p.invitable_type = 'User' AND p.invitable_id = u.id
      AND p.invitation_token = u.invitation_token
      AND p.invitation_accepted_at IS NULL AND p.superseded_at IS NULL AND p.revoked_at IS NULL);
