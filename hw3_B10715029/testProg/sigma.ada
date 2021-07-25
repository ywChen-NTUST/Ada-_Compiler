{* Sigma.sp
 *
 * Compute sum = 1 + 2 + ... + n
 *}
program computeSigma
-- constant and variable declarations
declare
  n: constant := 10;
  sum: integer;
  index: integer;

-- main statements
begin
  index := 0;
  sum := 0;
  while (index <= n) loop
    begin
      sum := sum + index;
      index := index + 1;
    end;
  end loop;
  print "The result is ";
  println sum;
end;
end computeSigma


