import json
import time
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

data_stream = [
    {"event_id": 1, "device": "sensor_A", "status": "NORMAL"},
    {"event_id": 2, "device": "sensor_B", "status": "WARNING"},
    {"event_id": 3, "device": "sensor_A", "status": "CRITICAL"}
]

for record in data_stream:
    producer.send('lab-events', record)
    print(f"Produced: {record}")
    time.sleep(1)

producer.flush()
