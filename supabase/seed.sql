-- ============================================================
--  UniDrive — données de démonstration pour Supabase
--
--  À exécuter dans Supabase Dashboard > SQL Editor, APRÈS schema.sql.
--  Le script peut être relancé : les comptes existants sont gardés et
--  les trajets de démonstration (id 9001 à 9010) sont recréés avec des
--  dates recalculées à partir d'aujourd'hui.
--
--  Comptes créés (mot de passe commun : Unidrive123!)
--    amine.trabelsi@unidrive.test   conducteur  (local_id usr_1001)
--    sarra.benali@unidrive.test     conductrice (usr_1002)
--    mehdi.jlassi@unidrive.test     conducteur  (usr_1003)
--    nour.hamdi@unidrive.test       passagère   (usr_1004)
--    youssef.gharbi@unidrive.test   passager    (usr_1005)
--    ines.mansouri@unidrive.test    passagère   (usr_1006)
--  Administrateur (mot de passe Admin123!, comme le compte local de l'app)
--    admin@esprit.tn                            (usr_admin_principal)
--
--  Les modules Trajets identifient l'utilisateur par un entier calculé
--  depuis local_id : usr_1001 → 1001 (voir idTrajetDe() dans
--  lib/core/constants/app_constants.dart).
-- ============================================================

-- ---------- Date d'un trajet : J+jours à hh:mm, heure de Tunis ----------
create or replace function pg_temp.d(jours integer, heure text)
returns timestamptz language sql stable as $$
  select (((now() at time zone 'Africa/Tunis')::date + jours) + heure::time)
         at time zone 'Africa/Tunis'
$$;

-- ============================================================
-- 1. UTILISATEURS (Supabase Auth + profiles)
-- ============================================================

drop table if exists seed_users;
create temporary table seed_users (
  local_id text, email text, mdp text, prenom text, nom text,
  telephone text, role text, gouvernorat text, note numeric,
  nb_trajets integer, marque text, modele text, couleur text,
  immat text, places integer
);

insert into seed_users values
  ('usr_1001', 'amine.trabelsi@unidrive.test', 'Unidrive123!', 'Amine', 'Trabelsi',
   '22111001', 'conducteur', 'Tunis', 4.7, 24, 'Kia', 'Picanto', 'Blanche', '215 TU 4521', 3),
  ('usr_1002', 'sarra.benali@unidrive.test', 'Unidrive123!', 'Sarra', 'Ben Ali',
   '22111002', 'conducteur', 'Tunis', 4.9, 31, 'Renault', 'Clio', 'Rouge', '198 TU 7733', 4),
  ('usr_1003', 'mehdi.jlassi@unidrive.test', 'Unidrive123!', 'Mehdi', 'Jlassi',
   '22111003', 'conducteur', 'Ben Arous', 4.5, 12, 'Volkswagen', 'Polo', 'Noire', '221 TU 1290', 4),
  ('usr_1004', 'nour.hamdi@unidrive.test', 'Unidrive123!', 'Nour', 'Hamdi',
   '22111004', 'passager', 'Ariana', 4.8, 9, null, null, null, null, 0),
  ('usr_1005', 'youssef.gharbi@unidrive.test', 'Unidrive123!', 'Youssef', 'Gharbi',
   '22111005', 'passager', 'Ben Arous', 4.6, 7, null, null, null, null, 0),
  ('usr_1006', 'ines.mansouri@unidrive.test', 'Unidrive123!', 'Ines', 'Mansouri',
   '22111006', 'passager', 'La Manouba', 5.0, 4, null, null, null, null, 0),
  ('usr_admin_principal', 'admin@esprit.tn', 'Admin123!', 'Admin ESPRIT', 'Responsable',
   '71123456', 'administrateur', 'Tunis', 5.0, 0, null, null, null, null, 0);

-- Comptes Auth (email déjà confirmé). Les emails déjà inscrits sont ignorés.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', gen_random_uuid(),
  'authenticated', 'authenticated', s.email,
  extensions.crypt(s.mdp, extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('prenom', s.prenom, 'nom', s.nom),
  now(), now(), '', '', '', ''
from seed_users s
where not exists (
  select 1 from auth.users u where lower(u.email) = lower(s.email)
);

-- Identité « email » (nécessaire pour se connecter avec email + mot de passe)
insert into auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(), u.id, u.id::text,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', now(), now(), now()
from auth.users u
join seed_users s on lower(u.email) = lower(s.email)
where not exists (
  select 1 from auth.identities i
  where i.user_id = u.id and i.provider = 'email'
);

-- Profils de l'application
insert into public.profiles (
  id, local_id, nom, prenom, email, telephone, "indicatifTel", role,
  "avatarUrl", gouvernorat, universite, note, "nombreTrajets",
  "marqueVehicule", "modeleVehicule", "couleurVehicule", immatriculation,
  "placesDisponibles", "dateInscription"
)
select
  u.id, s.local_id, s.nom, s.prenom, s.email, s.telephone, '+216', s.role,
  case when s.role = 'passager' then 'avatar_etudiant' else 'avatar_conducteur' end,
  s.gouvernorat, 'ESPRIT', s.note, s.nb_trajets,
  s.marque, s.modele, s.couleur, s.immat, s.places, now() - interval '60 days'
from auth.users u
join seed_users s on lower(u.email) = lower(s.email)
on conflict (id) do update set
  local_id = excluded.local_id,
  nom = excluded.nom,
  prenom = excluded.prenom,
  telephone = excluded.telephone,
  role = excluded.role,
  gouvernorat = excluded.gouvernorat,
  note = excluded.note,
  "nombreTrajets" = excluded."nombreTrajets",
  "marqueVehicule" = excluded."marqueVehicule",
  "modeleVehicule" = excluded."modeleVehicule",
  "couleurVehicule" = excluded."couleurVehicule",
  immatriculation = excluded.immatriculation,
  "placesDisponibles" = excluded."placesDisponibles";

drop table seed_users;

-- ============================================================
-- 2. TRAJETS (id 9001 à 9010)
-- ============================================================

-- Les données liées sont recréées à chaque exécution
delete from public.trajets where id between 9001 and 9010;  -- cascade

insert into public.trajets (
  id, conducteur_id, conducteur_nom, conducteur_note,
  ville_depart, adresse_depart, ville_arrivee, adresse_arrivee,
  date_depart, duree_minutes, distance_km, vehicule, capacite_vehicule,
  places_totales, places_disponibles, prix_place,
  bagages, fumeur, animaux, reservation_auto, description, statut,
  date_creation, lat_depart, lng_depart, lat_arrivee, lng_arrivee
) values
  (9001, 1001, 'Amine Trabelsi', 4.7,
   'Tunis', 'Place Barcelone', 'Ariana', 'ESPRIT, El Ghazala',
   pg_temp.d(1, '07:30'), 25, 14, 'Kia Picanto – Blanche', 4,
   3, 1, 3, true, false, false, true,
   'Départ à l''heure pour le cours de 8h30. Pas de détour possible.', 'publie',
   now() - interval '2 days', 36.7950, 10.1800, 36.8992, 10.1897),

  (9002, 1001, 'Amine Trabelsi', 4.7,
   'Ariana', 'ESPRIT, El Ghazala', 'Tunis', 'Place Barcelone',
   pg_temp.d(1, '17:30'), 30, 14, 'Kia Picanto – Blanche', 4,
   3, 3, 3, true, false, false, true,
   'Retour après les cours, tous les jours de la semaine.', 'publie',
   now() - interval '2 days', 36.8992, 10.1897, 36.7950, 10.1800),

  (9003, 1002, 'Sarra Ben Ali', 4.9,
   'La Marsa', 'Marsa Plage', 'Ariana', 'ESPRIT, El Ghazala',
   pg_temp.d(2, '08:00'), 20, 12, 'Renault Clio – Rouge', 5,
   4, 2, 3, true, false, false, false,
   'Trajet entre filles, musique douce et climatisation.', 'publie',
   now() - interval '1 day', 36.8782, 10.3247, 36.8992, 10.1897),

  (9004, 1002, 'Sarra Ben Ali', 4.9,
   'Tunis', 'Bab Saadoun', 'Sousse', 'Gare de Sousse',
   pg_temp.d(4, '14:00'), 130, 143, 'Renault Clio – Rouge', 5,
   3, 3, 15, true, false, true, false,
   'Week-end à Sousse, arrêt possible à Hammamet.', 'publie',
   now() - interval '1 day', 36.8065, 10.1815, 35.8256, 10.6084),

  (9005, 1003, 'Mehdi Jlassi', 4.5,
   'Ben Arous', 'Ben Arous centre', 'Ariana', 'ESPRIT, El Ghazala',
   date_trunc('hour', now()) + interval '2 hours', 30, 20, 'Volkswagen Polo – Noire', 5,
   3, 1, 4, true, false, false, true,
   'Départ devant la pharmacie de Ben Arous centre.', 'publie',
   now() - interval '3 days', 36.7531, 10.2189, 36.8992, 10.1897),

  (9006, 1003, 'Mehdi Jlassi', 4.5,
   'Nabeul', 'Gare routière de Nabeul', 'Tunis', 'Bab Alioua',
   pg_temp.d(3, '06:45'), 75, 68, 'Volkswagen Polo – Noire', 5,
   4, 0, 8, true, false, false, false,
   'Départ matinal, retour à Tunis pour la semaine.', 'complet',
   now() - interval '4 days', 36.4561, 10.7376, 36.7900, 10.1800),

  (9007, 1001, 'Amine Trabelsi', 4.7,
   'Tunis', 'Bab Saadoun', 'Bizerte', 'Corniche de Bizerte',
   pg_temp.d(-3, '09:00'), 60, 66, 'Kia Picanto – Blanche', 4,
   3, 1, 7, true, false, false, false,
   'Sortie à la plage de Bizerte.', 'termine',
   now() - interval '6 days', 36.8065, 10.1815, 37.2744, 9.8739),

  (9008, 1002, 'Sarra Ben Ali', 4.9,
   'Monastir', 'Université de Monastir', 'Sousse', 'Sahloul',
   pg_temp.d(-6, '16:00'), 25, 22, 'Renault Clio – Rouge', 5,
   3, 2, 3, true, false, false, false,
   'Retour de la journée portes ouvertes.', 'termine',
   now() - interval '9 days', 35.7643, 10.8113, 35.8256, 10.6084),

  (9009, 1003, 'Mehdi Jlassi', 4.5,
   'Bizerte', 'Centre-ville', 'Tunis', 'Place Barcelone',
   pg_temp.d(2, '18:00'), 60, 66, 'Volkswagen Polo – Noire', 5,
   3, 3, 7, true, false, false, false,
   'Trajet annulé (voiture au garage).', 'annule',
   now() - interval '2 days', 37.2744, 9.8739, 36.7950, 10.1800),

  (9010, 1001, 'Amine Trabelsi', 4.7,
   'Ariana', 'ESPRIT, El Ghazala', 'Tunis', 'Place Barcelone',
   pg_temp.d(8, '17:30'), 30, 14, 'Kia Picanto – Blanche', 4,
   3, 3, 3, true, false, false, true,
   'Retour après les cours, tous les jours de la semaine.', 'publie',
   now() - interval '2 days', 36.8992, 10.1897, 36.7950, 10.1800);

-- Les prochains trajets créés par l'application auront un id plus grand
select setval(
  pg_get_serial_sequence('public.trajets', 'id'),
  (select max(id) from public.trajets)
);

insert into public.trajet_etapes (trajet_id, ville, ordre, prix) values
  (9004, 'Hammamet', 1, 10);

-- Trajet régulier (même série) et trajet « Entre filles »
insert into public.options_trajet (trajet_id, serie_id, entre_filles) values
  (9002, 'serie_1001_esprit_tunis', false),
  (9010, 'serie_1001_esprit_tunis', false),
  (9003, null, true);

-- ============================================================
-- 3. RÉSERVATIONS, DISCUSSIONS, ÉVALUATIONS, ALERTES
-- ============================================================

insert into public.passagers_trajet
  (trajet_id, passager_id, nom, places, date_reservation, presence) values
  (9001, 1004, 'Nour Hamdi',     1, now() - interval '1 day',   'inconnue'),
  (9001, 1005, 'Youssef Gharbi', 1, now() - interval '20 hours', 'inconnue'),
  (9003, 1006, 'Ines Mansouri',  1, now() - interval '10 hours', 'inconnue'),
  (9003, 1004, 'Nour Hamdi',     1, now() - interval '8 hours',  'inconnue'),
  (9005, 1005, 'Youssef Gharbi', 2, now() - interval '2 days',   'inconnue'),
  (9006, 1004, 'Nour Hamdi',     1, now() - interval '3 days',   'inconnue'),
  (9006, 1006, 'Ines Mansouri',  1, now() - interval '3 days',   'inconnue'),
  (9006, 1005, 'Youssef Gharbi', 2, now() - interval '2 days',   'inconnue'),
  (9007, 1004, 'Nour Hamdi',     1, now() - interval '5 days',   'present'),
  (9007, 1006, 'Ines Mansouri',  1, now() - interval '5 days',   'present'),
  (9008, 1005, 'Youssef Gharbi', 1, now() - interval '8 days',   'present');

-- Discussion du trajet 9005 (départ dans moins de 2 h : discussion ouverte)
insert into public.messages_trajet (trajet_id, auteur_id, auteur_nom, texte, type, date) values
  (9005, 1003, 'Mehdi Jlassi',
   'Bonjour ! Je vous attends devant la pharmacie de Ben Arous centre.', 'texte',
   now() - interval '25 minutes'),
  (9005, 1005, 'Youssef Gharbi',
   'Parfait, on sera deux avec mon camarade. Merci !', 'texte',
   now() - interval '18 minutes'),
  (9005, 1003, 'Mehdi Jlassi',
   'Super, Polo noire, je serai là 5 minutes avant.', 'texte',
   now() - interval '10 minutes');

insert into public.evaluations_trajet
  (trajet_id, auteur_id, auteur_nom, cible_id, cible_nom, note, commentaire, date) values
  (9007, 1004, 'Nour Hamdi',     1001, 'Amine Trabelsi', 5,
   'Ponctuel · Conduite sûre · Très agréable, merci !', pg_temp.d(-3, '12:00')),
  (9007, 1006, 'Ines Mansouri',  1001, 'Amine Trabelsi', 4,
   'Sympathique · Petit retard au départ.', pg_temp.d(-3, '13:00')),
  (9007, 1001, 'Amine Trabelsi', 1004, 'Nour Hamdi',     5,
   'Passagère ponctuelle et agréable.', pg_temp.d(-3, '14:00')),
  (9008, 1005, 'Youssef Gharbi', 1002, 'Sarra Ben Ali',  5,
   'Très sympa, je recommande !', pg_temp.d(-6, '18:00'));

delete from public.alertes_trajet where user_id in (1004, 1005, 1006);
insert into public.alertes_trajet
  (user_id, ville_depart, ville_arrivee, places, date_creation) values
  (1004, 'Tunis',  'Sousse', 1, now() - interval '3 days'),
  (1005, 'Nabeul', 'Tunis',  1, now() - interval '1 day'),
  (1006, 'Tunis',  'Bizerte', 2, now() - interval '12 hours');

-- ============================================================
-- 4. MESSAGERIE (module d'Emna) — identifiants texte « usr_… »
-- ============================================================

delete from public.msg_conversation where id like 'conv_seed_%';  -- cascade

insert into public.msg_conversation
  (id, type, titre, trajet_id, trajet_label, createur_id, created_at) values
  ('conv_seed_prive_1', 'prive', '', null, '', 'usr_1004',
   now() - interval '1 day'),
  ('conv_seed_groupe_9001', 'groupe', 'Covoiturage Tunis → ESPRIT', '9001',
   'Tunis → Ariana', 'usr_1001', now() - interval '20 hours');

insert into public.msg_membre (conversation_id, user_id, nom, role, last_read_at) values
  ('conv_seed_prive_1',     'usr_1004', 'Nour Hamdi',     'passager',   now() - interval '1 hour'),
  ('conv_seed_prive_1',     'usr_1001', 'Amine Trabelsi', 'conducteur', now() - interval '3 hours'),
  ('conv_seed_groupe_9001', 'usr_1001', 'Amine Trabelsi', 'conducteur', now() - interval '2 hours'),
  ('conv_seed_groupe_9001', 'usr_1004', 'Nour Hamdi',     'passager',   now() - interval '2 hours'),
  ('conv_seed_groupe_9001', 'usr_1005', 'Youssef Gharbi', 'passager',   null);

insert into public.msg_message
  (id, conversation_id, expediteur_id, expediteur_nom, contenu, type, statut, date_envoi) values
  ('msg_seed_1', 'conv_seed_prive_1', 'usr_1004', 'Nour Hamdi',
   'Bonjour Amine, est-ce qu''il reste une place demain matin ?', 'texte', 'lu',
   now() - interval '1 day'),
  ('msg_seed_2', 'conv_seed_prive_1', 'usr_1001', 'Amine Trabelsi',
   'Oui, je viens de valider ta réservation 👍', 'texte', 'lu',
   now() - interval '23 hours'),
  ('msg_seed_3', 'conv_seed_prive_1', 'usr_1004', 'Nour Hamdi',
   'Merci beaucoup, à demain !', 'texte', 'livre',
   now() - interval '2 hours'),
  ('msg_seed_4', 'conv_seed_groupe_9001', 'usr_1001', 'Amine Trabelsi',
   'Salut à tous ! Rendez-vous à 7h25 place Barcelone, côté station de métro.', 'texte', 'lu',
   now() - interval '20 hours'),
  ('msg_seed_5', 'conv_seed_groupe_9001', 'usr_1005', 'Youssef Gharbi',
   'Bien noté, merci !', 'texte', 'envoye',
   now() - interval '3 hours');

-- ============================================================
-- 5. RÉCLAMATIONS
-- ============================================================

insert into public.reclamations
  (id, type, sujet, description, trajet, date, status, responses) values
  (9900001, 'retard', 'Retard de 20 minutes',
   'Le conducteur est arrivé avec 20 minutes de retard sans prévenir.',
   'Tunis → Bizerte', now() - interval '3 days', 'resolue',
   jsonb_build_array(jsonb_build_object(
     'message', 'Nous avons contacté le conducteur, qui s''excuse. Merci pour votre signalement.',
     'date', to_char((now() - interval '2 days') at time zone 'UTC',
                     'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
     'audioPath', null))),
  (9900002, 'paiement', 'Prix différent de l''annonce',
   'Le prix demandé sur place était de 10 DT au lieu de 7 DT.',
   'Monastir → Sousse', now() - interval '5 days', 'enCours', '[]'::jsonb),
  (9900003, 'vehicule', 'Climatisation en panne',
   'La climatisation ne fonctionnait pas pendant tout le trajet.',
   'Nabeul → Tunis', now() - interval '1 day', 'enAttente', '[]'::jsonb)
on conflict (id) do update set
  status = excluded.status,
  responses = excluded.responses,
  date = excluded.date;

-- Résumé
select 'profiles' as table_name, count(*) from public.profiles
union all select 'trajets', count(*) from public.trajets
union all select 'passagers_trajet', count(*) from public.passagers_trajet
union all select 'messages_trajet', count(*) from public.messages_trajet
union all select 'evaluations_trajet', count(*) from public.evaluations_trajet
union all select 'alertes_trajet', count(*) from public.alertes_trajet
union all select 'msg_conversation', count(*) from public.msg_conversation
union all select 'reclamations', count(*) from public.reclamations;
