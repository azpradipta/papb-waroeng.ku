class PublicInfoConfig {
  const PublicInfoConfig._();

  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '11231013@student.itk.ac.id',
  );
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
  );
}
