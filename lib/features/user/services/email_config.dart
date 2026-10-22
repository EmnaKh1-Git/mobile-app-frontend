class EmailConfig {
  static String serviceId = 'service_nnwytlc';
  static String templateId = 'template_fd6k9la';
  static String publicKey = 'djeXPzB4OOVjZo_cW';
  static String privateKey = '';
  static bool devModeMockEnabled = false;

  static bool get isConfigured =>
      serviceId.trim().isNotEmpty &&
      templateId.trim().isNotEmpty &&
      publicKey.trim().isNotEmpty;
}
