# YanTunnel Professional
 
   <p align="center">

<h2 align="center">
Auto Script Install XRAY/SSH Websocket Service
<img src="https://img.shields.io/badge/Release-v3.0-red.svg"></h2>

</p> 
<h2 align="center"> Supported Linux Distribution</h2>
<p align="center"><img src="https://d33wubrfki0l68.cloudfront.net/5911c43be3b1da526ed609e9c55783d9d0f6b066/9858b/assets/img/debian-ubuntu-hover.png"width="400"></p> 
<p align="center">
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%209&message=Stretch&color=purple"> 
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%2010&message=Buster&color=purple">  
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%2011&message=bullseye&color=purple"> 
<p align="center">
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=ubuntu%2018.04 LTS&message=Bionic Beaver&color=red"> 
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=ubuntu%2020.04 LTS&message=Focal Fossa&color=red"> 
</p>


- Debian 10, 11, 12, 13 dan versi yang lebih baru
- Ubuntu 20.04, 22.04, 24.04, 25.xx dan versi yang lebih baru
- Arsitektur `amd64` dan `arm64`

## Instalasi
<pre></pre>apt --fix-missing update && apt update && apt upgrade -y && apt install -y bzip2 gzip coreutils screen dpkg wget vim curl nano zip unzip && mkdir -p /root/yanstunnel && cd /root/yanstunnel && wget -q https://raw.githubusercontent.com/yansyntax/yanstunnel/main/setup.sh && wget -q https://raw.githubusercontent.com/yansyntax/yanstunnel/main/install.sh && chmod +x setup.sh install.sh && screen -S setup ./setup.sh && bash install.sh<code></code>

# note !
Installer akan mendeteksi IP publik VPS, mengambil daftar izin melalui HTTPS,
menolak IP yang tidak terdaftar, lalu menyimpan tanggal kedaluwarsa hasil
konversi masa aktif ke `/etc/yanstunnel/license.conf`.

## Perbaikan kompatibilitas

- Tidak lagi memaksa paket yang sudah dihapus dari Debian/Ubuntu modern seperti
  `python2`, `gnupg1`, dan `ntpdate`.
- Service menggunakan `systemctl` dengan fallback ke `service`.
- Xray memilih paket `amd64` atau `arm64` sesuai arsitektur.
- Bridge websocket SSH sudah menggunakan Python 3.
- Konfigurasi Nginx menggunakan TLS 1.2/1.3 dan valid untuk IPv4/IPv6.
- Token GitHub yang tertanam di script lama dihapus. Backup GitHub sekarang
  menggunakan remote yang sudah dikonfigurasi pengguna.