import { asset } from '@kit.AssetStoreKit';
import util from '@ohos.util';
import { CurrentUser, Identity } from '../models/CommonModels';

export class SessionStore {
  static token: string = '';
  static user: CurrentUser | undefined = undefined;
  static roles: string[] = [];
  static permissions: string[] = [];
  private static readonly alias: Uint8Array = new util.TextEncoder().encodeInto('iiop_mobile_session');
  private static unauthorizedHandler: (() => void) | undefined = undefined;

  static initialize(context: Object): void {}

  static async restoreToken(): Promise<string> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, SessionStore.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows = await asset.query(query);
      const secret = rows.length > 0 ? rows[0].get(asset.Tag.SECRET) : undefined;
      SessionStore.token = secret instanceof Uint8Array ? new util.TextDecoder().decodeToString(secret) : '';
    } catch (error) { SessionStore.token = ''; }
    return SessionStore.token;
  }

  static async applyIdentity(identity: Identity): Promise<void> {
    if (identity.tokenValue !== undefined) SessionStore.token = identity.tokenValue;
    SessionStore.user = identity.user;
    SessionStore.roles = identity.roles ?? [];
    SessionStore.permissions = identity.permissions ?? [];
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, SessionStore.alias);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(SessionStore.token));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    await asset.add(attributes);
    console.info(`[AUTH] session -> tokenPresent=${SessionStore.token.length > 0} userPresent=${SessionStore.user !== undefined} roles=${SessionStore.roles.join(',')} permissionsCount=${SessionStore.permissions.length}`);
  }

  static async clearIdentity(): Promise<void> {
    SessionStore.token = '';
    SessionStore.user = undefined;
    SessionStore.roles = [];
    SessionStore.permissions = [];
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, SessionStore.alias);
    try { await asset.remove(query); } catch (error) {}
  }

  static registerUnauthorizedHandler(handler: () => void): void {
    SessionStore.unauthorizedHandler = handler;
  }

  static notifyUnauthorized(): void {
    SessionStore.unauthorizedHandler?.();
  }

  static hasRole(role: string): boolean { return SessionStore.roles.includes(role); }
}
