import json
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'lab-events',
    bootstrap_servers=['localhost:9092'],
    auto_offset_reset='earliest',
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

print("Listening for incoming stream events...")
for message in consumer:
    event = message.value
    print(f"Received Event: {event['event_id']} | Device: {event['device']} | Status: {event['status']}")
