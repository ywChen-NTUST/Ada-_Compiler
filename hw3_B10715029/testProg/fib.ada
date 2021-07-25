{ This test program computes the Nth Fibonacci number
    using recursion and iteration. }

program computeFib

-- global variables
declare
  n: constant := 8;

-- recursive function
procedure recFibonacci (n: integer) return integer
begin
  if ((n = 1) or (n = 2)) then
    return 1;
  end if;

  return (recFibonacci(n-1) + recFibonacci(n-2));
end;
end recFibonacci;

-- iterative function
procedure itFibonacci (n: integer) return integer
declare
  Fn: integer;
  FNminus1: integer;
  temp: integer;

begin
  Fn := 1;
  FNminus1 := 1;
  while (n > 2) loop
    begin
      temp := Fn;
      Fn := Fn + FNminus1;
      FNminus1 := temp;
      n := n - 1;
    end;
  end loop;
  return Fn;
end;
end itFibonacci;

-- main program 
begin
  print "N: ";
  println n;
  print "Result of recursive computation:";
  println recFibonacci(n);
  print "Result of iterative computation:";
  println itFibonacci(n);
end;
end computeFib


