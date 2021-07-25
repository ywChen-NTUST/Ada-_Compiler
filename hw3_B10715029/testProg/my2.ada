program AA
declare
	a : boolean := true;
	gg : boolean := false;
	t1: constant: integer := 12+56;
	t2: integer := 12+56;
	t3 := t2 + t1 + 7;
	t4 : integer;
procedure aa(b: boolean)
declare
	a: constant: boolean := true;
	c: boolean;
	d := not (true and false);
begin
	println a;
	println(b);
	c := a and b;
	println(c);
	print(d);
end;
end aa;
begin
	aa(gg);
	aa(a);
	println(t1); -- sipush has restrict of max value -128 ~ 127
	println(t2);
	println(not a);
	println(gg);
	println(t1 = t2);
	println((not a) = gg);
	if((t1 = t2) and ((not a) = gg)) then
	begin
		aa(gg or a);
		println("");
		println(t1);
		println(t2);
	end;
	end if;
	for(t4 in 1..10) loop
	begin
		println(t4*10);
	end;
	end loop;
end;
end AA
