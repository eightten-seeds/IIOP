export class NetworkConfig {
  // HarmonyOS Emulator reaches the Windows host through the QEMU host alias.
  // This is the only Gateway address in application source.
  static readonly gatewayBaseUrl: string = 'http://10.0.2.2:8080';
  static readonly gatewayHost: string = '10.0.2.2:8080';
  static readonly timeoutMs: number = 20000;
}
