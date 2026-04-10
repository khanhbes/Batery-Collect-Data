const String openWeatherApiKey = String.fromEnvironment(
  'OPENWEATHER_API_KEY',
  defaultValue: '147ef7681c1d20684da6a5d6bad31136',
);

const String movementWebhookUrl = String.fromEnvironment(
  'MOVEMENT_WEBHOOK_URL',
  defaultValue:
      'https://script.google.com/macros/s/AKfycbxhq1cxeD8sNH9IQ-bfWUFQzJFUauFq3h0bytW9qN7if1p7WE0lbRezYuVpXuB88dQs/exec',
);

const String chargingWebhookUrl = String.fromEnvironment(
  'CHARGING_WEBHOOK_URL',
  defaultValue:
      'https://script.google.com/macros/s/AKfycbxhq1cxeD8sNH9IQ-bfWUFQzJFUauFq3h0bytW9qN7if1p7WE0lbRezYuVpXuB88dQs/exec',
);

const String driveWebhookApiKey = String.fromEnvironment(
  'DRIVE_WEBHOOK_API_KEY',
  defaultValue: '4d7f6a2c9b1e43f8a5d0c2e7b9f1a6c34e8d2b7a5c1f9d6e0b3a7c2d8e4f1a9',
);
