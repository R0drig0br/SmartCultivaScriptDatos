#!/usr/bin/env python3

import os
import time
import Adafruit_DHT as dht
import paho.mqtt.client as mqtt
import json
import RPi.GPIO as GPIO

# Configuración de ThingsBoard
THINGSBOARD_HOST = 'iot.ceisufro.cl'
ACCESS_TOKEN = 'veuyn5cfZ2Tf1wYNK3mo'

# Configuración del sensor DHT11
DHT_SENSOR = dht.DHT11
DHT_PIN = 23

# Configuración del intervalo de envío
INTERVAL = 10

# Configuración del sensor de resistencia
mpin = 17
tpin = 27
GPIO.setmode(GPIO.BCM)
cap = 0.000001
adj = 2.130620985

sensor_data = {'temperature': 0, 'humidity': 0, 'resistance': 0}

next_reading = time.time()

client = mqtt.Client()
client.username_pw_set(ACCESS_TOKEN)
client.connect(THINGSBOARD_HOST, 1883, 60)
client.loop_start()

try:
    while True:
        # Medir temperatura y humedad
        humidity, temperature = dht.read_retry(DHT_SENSOR, DHT_PIN)
        humidity = round(humidity, 2)
        temperature = round(temperature, 2)

        # Medir resistencia
        GPIO.setup(mpin, GPIO.OUT)
        GPIO.setup(tpin, GPIO.OUT)
        GPIO.output(mpin, False)
        GPIO.output(tpin, False)
        time.sleep(0.2)
        GPIO.setup(mpin, GPIO.IN)
        time.sleep(0.2)
        GPIO.output(tpin, True)
        starttime = time.time()
        endtime = time.time()
        while GPIO.input(mpin) == GPIO.LOW:
            endtime = time.time()
        measureresistance = endtime - starttime
        resistance = (measureresistance / cap) * adj

        print(u"Temperatura: {:g}°C, Humedad: {:g}%, Resistencia: {:g}".format(
            temperature, humidity, resistance))

        # Actualizar datos del sensor
        sensor_data['temperature'] = temperature
        sensor_data['humidity'] = humidity
        sensor_data['resistance'] = resistance

        # Enviar datos a ThingsBoard
        client.publish('v1/devices/me/telemetry', json.dumps(sensor_data), 1)

        next_reading += INTERVAL
        sleep_time = next_reading - time.time()
        if sleep_time > 0:
            time.sleep(sleep_time)

except KeyboardInterrupt:
    pass

finally:
    client.loop_stop()
    client.disconnect()
    GPIO.cleanup()

