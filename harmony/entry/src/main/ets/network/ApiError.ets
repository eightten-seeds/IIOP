export enum ApiErrorKind { Unauthorized, Forbidden, NotFound, Conflict, Service, Network, Business }

export class ApiError extends Error {
  kind: ApiErrorKind;
  status: number;

  constructor(message: string, kind: ApiErrorKind, status: number = 0) {
    super(message);
    this.kind = kind;
    this.status = status;
  }
}
