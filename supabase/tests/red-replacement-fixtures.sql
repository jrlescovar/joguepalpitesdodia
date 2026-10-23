-- Prepend to the Red migration in a rollback transaction; fixture checks in red-replacement-checks.sql.
begin;
insert into public.public_profiles(id,player_id,username,avatar_color,pass_name_style,pass_border_style) values
 ('11111111-1111-4111-8111-111111111111',9900301,'redqa1','#3b82f6','blood','purple'),
 ('22222222-2222-4222-8222-222222222222',9900302,'redqa2','#3b82f6','green','blood'),
 ('33333333-3333-4333-8333-333333333333',9900303,'redqa3','#3b82f6','blood','blood'),
 ('44444444-4444-4444-8444-444444444444',9900304,'redqa4','#3b82f6','none','none'),
 ('55555555-5555-4555-8555-555555555555',9900305,'redqa5','#3b82f6','none','none');
insert into public.private_profiles(profile_id,auth_user_id,email) values
 ('33333333-3333-4333-8333-333333333333','66666666-6666-4666-8666-666666666666','redqa3@example.invalid');
insert into public.box_inventory(profile_id,kind,style,acquired_at) values
 ('33333333-3333-4333-8333-333333333333','name','blood',now()-interval '2 days'),
 ('33333333-3333-4333-8333-333333333333','frame','halloween-bloodmoon',now()-interval '3 days'),
 ('44444444-4444-4444-8444-444444444444','name','blood',now()-interval '2 days'),
 ('44444444-4444-4444-8444-444444444444','frame','blood',now()-interval '2 days'),
 ('44444444-4444-4444-8444-444444444444','frame','purple',now()-interval '3 days');
insert into public.player_mail(profile_id,kind,style,quantity,created_at) values
 ('55555555-5555-4555-8555-555555555555','frame','blood',1,now()-interval '2 days'),
 ('55555555-5555-4555-8555-555555555555','frame','halloween-bloodmoon',1,now()-interval '1 day');
