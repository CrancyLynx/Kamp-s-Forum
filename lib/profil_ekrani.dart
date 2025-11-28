import 'package:flutter/material.dart';
import 'kullanici_profil_detay_ekrani.dart'; 

class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    // userId null gönderilirse, ProfilSayfasi otomatik olarak "Benim Profilim" modunda açılır.
    return const KullaniciProfilDetayEkrani(userId: null);
  }
}