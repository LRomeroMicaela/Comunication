-- 1. Show all the columns order by order_id
SELECT *
FROM CC_chat_msg
ORDER BY 
	order_id;

-- 2. Show all the columns order by city_code
SELECT *
FROM CC_chat_msg LEFT JOIN orders
ON
	CC_chat_msg.order_id = orders.order_id
ORDER BY 
	city_code;

--3. Show the first message (row) sender (courier or customer)
SELECT TOP (1)
	sender_app_type,
	message_sent_time
FROM CC_chat_msg
ORDER BY 
	message_sent_time;

-- 4. Show the number of messages sent by customer and order_id
SELECT 
	sender_app_type, 
	order_id,
COUNT(sender_app_type) AS num_message
FROM CC_chat_msg
WHERE 
	sender_app_type LIKE 'Customer%'
GROUP BY 
	order_id, 
	sender_app_type;

--5. Show the first message (row) in the conversation by order_id
SELECT
    order_id,
    MIN(message_sent_time) AS first_message
FROM CC_chat_msg
GROUP BY
    order_id;

-- 6. Show the last message (row) in the conversation by order_id 
SELECT
    order_id,
    message_sent_time
FROM CC_chat_msg cm1
WHERE
    message_sent_time = (
        SELECT MAX(message_sent_time)
        FROM CC_chat_msg
    );


-- 7. Show the time (in secs) elapsed until the first message 
-- was responded by order_id

SELECT
    c.order_id,
    ABS(DATEDIFF(SECOND, c.received_datetime, r.responded_datetime)) 
	AS time_elapsed_seconds
FROM
    (SELECT 
        order_id,
        MIN(message_sent_time) AS received_datetime
     FROM CC_chat_msg
     WHERE sender_app_type LIKE 'Customer%'
     GROUP BY order_id) AS c
    JOIN
    (SELECT 
        order_id,
        MIN(message_sent_time) AS responded_datetime
     FROM CC_chat_msg
     WHERE sender_app_type LIKE 'Courier%'
     GROUP BY order_id) AS r
    ON c.order_id = r.order_id;

-- 8. Build a query that aggregates individual messages into conversations.
-- The query result should be used to create a table 
-- customer_courier_conversations. 

CREATE TABLE customer_courier_conversations (
    order_id SMALLINT PRIMARY KEY NOT NULL ,
    city_code NVARCHAR(50),
    first_courier_message DATETIME2(7),
    first_customer_message DATETIME2(7),
    num_messages_courier INT,
    num_messages_customer INT,
    first_message_by NVARCHAR(50),
    conversation_started_at DATETIME2(7),
    first_responsetime_delay_segundos INT,
    last_message_time DATETIME2(7),
    last_message_order_stage NVARCHAR(50)
);

-- Insertar datos en la tabla customer_courier_conversations
INSERT INTO customer_courier_conversations (
    CC_chat_msg.order_id,
    city_code,
    first_courier_message,
    first_customer_message,
    num_messages_courier,
    num_messages_customer,
    first_message_by,
    conversation_started_at,
    first_responsetime_delay_segundos,
    last_message_time,
    last_message_order_stage
)
SELECT
    CC_chat_msg.order_id,
    city_code,
    MIN(CASE WHEN sender_app_type LIKE 'Courier%' THEN message_sent_time END) 
	AS first_courier_message,
    MIN(CASE WHEN sender_app_type LIKE 'Customer%' THEN message_sent_time END) 
	AS first_customer_message,
    COUNT(CASE WHEN sender_app_type LIKE 'Courier%' THEN 1 END) 
	AS num_messages_courier,
    COUNT(CASE WHEN sender_app_type LIKE 'Customer%' THEN 1 END) 
	AS num_messages_customer,
    CASE
    WHEN MIN(CASE WHEN sender_app_type LIKE 'Courier%' THEN message_sent_time END) IS NOT NULL
         AND (MIN(CASE WHEN sender_app_type LIKE 'Customer%' THEN message_sent_time END) IS NULL
              OR MIN(CASE WHEN sender_app_type LIKE 'Courier%' THEN message_sent_time END) 
			  < MIN(CASE WHEN sender_app_type LIKE 'Customer%' THEN message_sent_time END))
    THEN 'Courier'
    ELSE 'Customer'
	END AS first_message_by,
    MIN(message_sent_time) AS conversation_started_at,
   COALESCE(
   ABS(
    DATEDIFF(
        SECOND,
        MIN(CASE WHEN sender_app_type LIKE 'Customer%' THEN message_sent_time END),
        MIN(CASE WHEN sender_app_type LIKE 'Courier%' THEN message_sent_time END)
    )),0) AS first_responsetime_delay_segundos,
    MAX(message_sent_time) AS last_message_time,
    MAX(order_stage) AS last_message_order_stage
FROM
    CC_chat_msg LEFT JOIN orders
ON CC_chat_msg.order_id = orders.order_id
GROUP BY
    CC_chat_msg.order_id,
    city_code;

