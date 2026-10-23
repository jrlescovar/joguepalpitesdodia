-- Keep Google avatars and permit only the nine supplied bot photos on our host.
alter table public.public_profiles drop constraint valid_google_avatar_url;
alter table public.public_profiles add constraint valid_google_avatar_url check(
 avatar_url is null
 or avatar_url like 'https://lh3.googleusercontent.com/%'
 or avatar_url ~ '^https://joguepalpitesdodia[.]web[.]app/avatars/bot[1-9]-[a-f0-9]{12}[.]webp$'
);
