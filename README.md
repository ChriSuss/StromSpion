Serverinstallation
1. Installation Raspberry Pi 3 mit  [Raspberry Pi Imager](https://www.raspberrypi.com/software/) auf z.B. Ubuntu 24.04.3 LTS
	1. Benutzernamen festlegen
	2. Netzwerk verbinden; Hostname $master festlegen
	3. SSH aktivieren
2. Nach Installation per SSH auf $master einloggen
3. Update OS
	1. Aktualisierung Distribution
	   `sudo apt update`
	   `sudo apt dist-upgrade`
	2. Danach einen Neustart
	   `sudo reboot`
	3. Keyboard-Layout konfigurieren
	   `sudo dpkg-reconfigure keyboard-configuration`
	4. Zeitzone checken
	   `sudo dpkg-reconfigure tzdata`
4. SD-Card sichern und zurückspielen
	1. Sichern
	   `sudo dd if=/dev/mmcblk0 of=sd-card-backup_fresh-and-updated.img bs=1M status=progress`
	2. Schreiben
	   `sudo dd if=sd-card-backup_fresh-and-updated.img of=/dev/mmcblk0 bs=1M status=progress`
5. Einrichtung [Mosquitto](https://mosquitto.org/) als MQTT Broker
	1. Installation Mosquitto und der MQTT-Clients zum testweise Senden und Empfangen von MQTT-Nachrichten
	   `sudo apt install mosquitto mosquitto-clients`
	2. Konfiguration Autostart und Status-Check
	   `sudo systemctl enable mosquitto` bzw.  `sudo systemctl disable mosquitto`
	   `sudo systemctl status mosquitto`
	3. Kommunikation mit Authentifizierung mit Benutzername und Passwort einrichten
	   `sudo mosquitto_passwd -c /etc/mosquitto/credentials $TasmotaUser` und anschließend im Dialog ein $TasmotaPassword vergeben
	   `sudo nano /etc/mosquitto/conf.d/local.conf`
		   *listener 1883*
		   *allow_anonymous false*
		   *password_file /etc/mosquitto/credentials*
	4. ==!!! Wichtig !!!== Der neu generierten credentials Datei die korrekten Zugriffsrechte geben
	   `sudo chmod u=rw,g=r,o=r /etc/mosquitto/credentials`
	5. Danach einen Neustart, oder zumindest Neustart Mosquitto
	   `sudo reboot`
	   `sudo systemctl restart mosquitto`
	6. Test der Kommunikation über Netzwerk
	   Auf dem Broker/Server einen Subscriber-Client mit USER und PASSWORD starten
	   `mosquitto_sub -t "#" -v -u $TasmotaUser -P $TasmotaPassword`
	   Auf einem Publisher eine Message absetzen
	   `mosquitto_pub -h stromspionmaster -t TEST -m "Hallo Welt" -u USER -P PASSWORD`
	   ==!!! Oder !!!== Hier einfach schon die Botschaften vom Sensor mitschreiben
6. Einrichtung Log2RAM
	1. [Log2RAM](https://github.com/azlux/log2ram) installieren, um die SD-Karte vor zu vielen Schreibzugriffen zu entlasten
	   `curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf -`
	   `cd log2ram-master`
	   `chmod +x install.sh && sudo ./install.sh`
	   `cd ..`
	   `rm -r log2ram-master`
	2. Danach einen Neustart
	   `sudo reboot`
	3. Testen
	   `systemctl status log2ram`
7. Einrichtung von [InfluxDB](https://docs.influxdata.com/influxdb3/core/)
	1. Installation von InfluxDB2 (bewusste Entscheidung, weil InfluxDB3 zum aktuellen Zeitpunkt noch nicht als APT Paket verfügbar, und anscheinend kein integrierter Webserver mehr)
	   `sudo apt install -y curl gnupg2 software-properties-common`
	   `curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | sudo gpg --dearmor -o /usr/share/keyrings/influxdb-keyring.gpg`
	   `echo 'deb [signed-by=/usr/share/keyrings/influxdb-keyring.gpg] https://repos.influxdata.com/ubuntu jammy stable' | sudo tee /etc/apt/sources.list.d/influxdb.list`
	   `sudo apt update`
	   `sudo apt install influxdb2`
	2. Danach einen Neustart
	   `sudo reboot`
	3. Starten und als Service einrichten
	   `sudo systemctl start influxdb`
	   `sudo systemctl enable influxdb`	   
	4. Testen
	   `sudo systemctl status influxdb`
	5. Setup im Browser fertigstellen
	   `http://<your_server_ip>:8086`
	6. $influxDBUser $influxDBPassword merken
8. Einrichtung von Telefgraf
	1. Telegraf als Plugin für InfluxDB zum Einlesen der MQTT Nachrichten `bash curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key gpg --show-keys --with-fingerprint --with-colons ./influxdata-archive.key 2>&1 \ | grep -q '^fpr:\+24C975CBA61A024EE1B631787C3D57159FC2F927:$' \ && cat influxdata-archive.key \ | gpg --dearmor \ | sudo tee /etc/apt/keyrings/influxdata-archive.gpg > /dev/null \ && echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' \ | sudo tee /etc/apt/sources.list.d/influxdata.list sudo apt-get update && sudo apt-get install telegraf`
	   
9. Tasmota Skript anpassen
	1. Testen mit https://tasmota-sml-parser.dicp.net/decode
	   `sensor53 d1`
	   `senssor53 d0`
	2. Wichtig - kann sein, dass das lange Protokoll noch nicht aktiviert ist. Hier https://www.manualslib.de/manual/409099/Ebz-Dd3.html?page=14#manual in Kapitel 12 nachlesen
	3. Außerdem Tipp, den oberen - meist hinter einem Aufkleber versteckten - optischen Leser zu verwenden