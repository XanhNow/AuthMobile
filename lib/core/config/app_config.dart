class AppConfig {
  const AppConfig({
    required this.securityBaseUrl,
    required this.contractVersion,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      securityBaseUrl: String.fromEnvironment(
        'XANHNOW_SECURITY_BASE_URL',
        defaultValue: 'https://api.ioxy.site/security',
      ),
      contractVersion: String.fromEnvironment(
        'XANHNOW_CONTRACT_VERSION',
        defaultValue: 'v1',
      ),
    );
  }

  final String securityBaseUrl;
  final String contractVersion;
}
