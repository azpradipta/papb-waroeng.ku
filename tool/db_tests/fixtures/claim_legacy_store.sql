do $$
declare v_user uuid; v_target uuid; v_owner uuid; v_legacy uuid;
begin
  select p.id, p.store_id, s.owner_id into v_user, v_target, v_owner
  from public.profiles p join auth.users u on u.id = p.id
  join public.stores s on s.id = p.store_id
  where u.email = 'EMAIL_PEMILIK_YANG_DIPILIH';
  if v_user is null then raise exception 'Email tidak ditemukan.'; end if;
  if v_owner is not null and v_owner <> v_user then
    raise exception 'Akun ini terikat pada toko Pemilik lain.';
  end if;
  update public.stores set owner_id = v_user where id = v_target;
  update public.profiles set role = 'Pemilik', is_active = true where id = v_user;
  for v_legacy in select id from public.stores where owner_id is null
  loop
    update public.products set store_id = v_target where store_id = v_legacy;
    update public.transactions set store_id = v_target where store_id = v_legacy;
    update public.profiles set store_id = v_target where store_id = v_legacy;
    delete from public.stores where id = v_legacy;
  end loop;
end;
$$;
