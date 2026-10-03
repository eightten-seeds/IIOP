export class BackNavigationStore {
  private static handler: (() => boolean) | undefined = undefined;
  private static owner: string = '';

  static register(owner: string, handler: () => boolean): void {
    BackNavigationStore.owner = owner;
    BackNavigationStore.handler = handler;
  }

  static clear(owner: string): void {
    if (BackNavigationStore.owner === owner) {
      BackNavigationStore.owner = '';
      BackNavigationStore.handler = undefined;
    }
  }

  static handle(): boolean {
    return BackNavigationStore.handler?.() ?? false;
  }
}
