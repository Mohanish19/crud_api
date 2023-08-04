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


--  Problems on Functions

-- Calculate square of Number
CREATE OR REPLACE FUNCTION calculate_sqr(num NUMBER) RETURN NUMBER IS
    square NUMBER;
BEGIN
    square := num * num;
    RETURN square;
END;

-- Convert Celcius to Fahrenheit 
CREATE OR REPLACE FUNCTION celcius_to_fahrenheit(celcius NUMBER) RETURN NUMBER IS
    fahrenheit NUMBER;
BEGIN
    fahrenheit := (celcius * 9/5) + 32;
    RETURN fahrenheit;
END;

CREATE OR REPLACE FUNCTION even_number(num NUMBER) RETURN BOOLEAN IS
BEGIN
    IF num MOD 2 = 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;

-- Find greatest of three numbers

CREATE OR REPLACE FUNCTION find_greatest(num1 NUMBER, num2 NUMBER, num3 NUMBER) RETURN NUMBER IS
    greatest_num NUMBER;
BEGIN
    IF num1 >= num2 AND num1 >= num3 THEN
    greatest_num := num1;
    ELSE IF num2 >= num1 AND num2 >= num3 THEN
    greatest_num := num2;
    ELSE 
    greatest_num := num3;
    END IF;
    RETURN greatest_num;
END;

-- Factorial of a Number using Recursion 

CREATE OR REPLACE FUNCTION factorial_recursive(num NUMBER) RETURN NUMBER IS
BEGIN 
    IF num = 0 THEN
        RETURN 1;
    ELSE 
        RETURN num * factorial_recursive(num - 1);
    END IF;
END;

-- Check if a String is Palindrome:
CREATE OR REPLACE FUNCTION is_palindrome(input_str VARCHAR2) RETURN BOOLEAN IS
    reversed_str VARCHAR2(100);
BEGIN
    reversed_str := REVERSE(input_str);
    IF input_str = reversed_str THEN
        RETURN TRUE;
    ELSE 
        RETURN FALSE;
    END IF;
END;

--  Calculate fibonacci Number

CREATE OR REPLACE FUNCTION fib(n NUMBER) RETURN NUMBER IS
BEGIN 
    IF  n <= 0 THEN
        RETURN 0;
    ELSE IF n = 1 THEN
        RETURN 1;
    ELSE
        RETURN fib(n - 1) + ( n - 2 );
    END IF;
END;

-- Convert Minutes to Hours and Minutes
CREATE OR REPLACE FUNCTION min_to_hours_min(total_min NUMBER) RETURN NUMBER IS
    hours NUMBER;
    remaining_min := total_min MOD 60;
    RETURN TO_CHAR(hours) || ' hours ' || TO_CHAR(remaining_min) || ' minutes';
END;