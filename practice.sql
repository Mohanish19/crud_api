-- Hello World
DECLARE 
message varchar2(100) := 'Hello World';
BEGIN
dbms_output.put_line(message);
END
/

-- Area of rectangle 
DECLARE
    len NUMBER := 5;
    width NUMBER := 3;
    area NUMBER;
BEGIN
    area := len * width;
    dbms_output.put_line('Area: ' || area);
END
/

-- Maximum of two number 

DECLARE
    a NUMBER := 10;
    b NUMBER := 20;
    max NUMBER;
BEGIN
    IF a > b THEN
    max := a;
    ELSE 
    max := b;
    END IF;
    dbms_output.put_line('Maximum: ' || max);
END
/

-- Factorial

DECLARE
    a NUMBER := 5;
    factorial NUMBER := 1;
BEGIN
    FOR i IN 1..a LOOP
    factorial := factorial * i;
    END LOOP
    dbms_output.put_line('Factorial of ' || a || ':' || factorial);
END
/

-- Display Employee Names

DECLARE
    emp_name varchar2(100);
    CURSOR employee_cur IS
    SELECT first_name || ' ' || last_name AS full_name
    FROM employee;
BEGIN
    OPEN employee_cur;
    LOOP
    FETCH employee_cur INTO emp_name;
    EXIT WHEN employee_cur%NOTFOUND;
    dbms_output.put_line(emp_name);
    END LOOP
    CLOSE employee_cur;
END;
/

-- Average of Numbers

DECLARE
    total NUMBER := 0;
    count NUMBER := 0;
    avg NUMBER;
BEGIN
    FOR i IN 1..10 LOOP
    total := total + i;
    count++;
    END LOOP;
    avg := total / count;
    dbms_output.put_line('Average: ' || avg);
END
/


-- Basic maths problem
DECLARE 
a integer := 10;
b integer := 20;
c integer;
f real
BEGIN
c := a + b;
dbms_output.put_line(c);
f := 70.0/3.0;
dbms_output.put_line(f);

END

/