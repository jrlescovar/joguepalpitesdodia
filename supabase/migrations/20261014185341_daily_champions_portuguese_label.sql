begin;
-- Translate the competition name only; preserve market options, rewards and results.
update public.predictions set
 title=regexp_replace(title,'\m(UEFA[[:space:]]+)?Champions[[:space:]]+League\M','Liga dos Campeões','gi'),
 description=regexp_replace(description,'\m(UEFA[[:space:]]+)?Champions[[:space:]]+League\M','Liga dos Campeões','gi')
where title ~* '\m(UEFA[[:space:]]+)?Champions[[:space:]]+League\M'
   or description ~* '\m(UEFA[[:space:]]+)?Champions[[:space:]]+League\M';
commit;
