import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Politique de confidentialité')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          Text(
            'UniDrive',
            style: TextStyle(
              color: AppColors.primaire,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Politique de confidentialité — dernière mise à jour : 26 octobre 2026',
            style: TextStyle(color: AppColors.texte2),
          ),
          SizedBox(height: 24),
          _PolicySection(
            title: 'Version française',
            body:
                'UniDrive est une application de covoiturage étudiant éditée par Emna Kh. '
                'Nous collectons uniquement les informations nécessaires à la création '
                'du compte et à la mise en relation : nom, prénom, adresse e-mail, '
                'numéro de téléphone, établissement, gouvernorat, photo de profil et '
                'informations relatives aux trajets. La localisation et les fichiers '
                'audio ou image sont utilisés uniquement lorsque vous activez la '
                'fonction correspondante.\n\n'
                'Ces données servent à authentifier votre compte, afficher votre profil, '
                'organiser les trajets et assurer la sécurité de la communauté. Elles '
                'sont stockées dans Supabase et dans le cache local de l’application. '
                'Nous ne vendons pas vos données et ne les partageons pas à des fins '
                'publicitaires. Vous pouvez demander l’accès, la rectification ou la '
                'suppression de vos données en contactant support@covoiturage-etudiant.tn.\n\n'
                'Vous pouvez retirer les autorisations accordées dans les réglages de '
                'votre appareil. La suppression du compte entraîne la suppression des '
                'données de profil associées, sous réserve des obligations légales.',
          ),
          SizedBox(height: 24),
          _PolicySection(
            title: '中文版本',
            body:
                'UniDrive 是由 Emna Kh 开发的学生拼车应用。我们仅收集创建账户和 '
                '提供服务所必需的信息，包括姓名、电子邮箱、电话号码、学校、 '
                '省份、头像以及行程信息。只有在您使用相应功能时，我们才会使用 '
                '定位、图片或音频权限。\n\n'
                '这些信息用于验证账户、显示个人资料、安排拼车行程以及保护社区安全。'
                '数据存储在 Supabase 和应用的本地缓存中。我们不会出售您的个人信息，'
                '也不会将其用于广告。您可以通过 '
                'support@covoiturage-etudiant.tn 联系我们，申请访问、更正或删除您的数据。\n\n'
                '您可以在设备设置中撤销已授予的权限。删除账户后，与个人资料相关的数据'
                '将被删除，但法律要求保留的数据除外。',
          ),
          SizedBox(height: 24),
          Text(
            'Développeur / 开发者 : Emna Kh',
            style: TextStyle(
              color: AppColors.texte,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaire,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(
            color: AppColors.texte,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
