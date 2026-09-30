import { defineStore } from 'pinia';
import { request } from '../api/request';

const HOME_ROLE_PRIORITY=['SUPER_ADMIN','ADMIN','MAINTAINER','INSPECTOR'];

export const useAuthStore=defineStore('auth',{
  state:()=>({token:'',currentUser:null as any,roles:[] as string[],permissions:[] as string[],unread:0}),
  persist:true,
  actions:{
    applyIdentity(data:any){this.currentUser=data?.user??null;this.roles=Array.isArray(data?.roles)?data.roles:[];this.permissions=Array.isArray(data?.permissions)?data.permissions:[]},
    identityIncomplete(){return !this.currentUser||!Array.isArray(this.roles)||!this.roles.length||!Array.isArray(this.permissions)||!this.permissions.length},
    defaultHome(){const role=HOME_ROLE_PRIORITY.find(role=>this.roles.includes(role));return role==='INSPECTOR'?'/inspection/tasks':role==='MAINTAINER'?'/maintenance/work-orders':'/dashboard'},
    async login(username:string,password:string){const r:any=await request.post('/api/auth/login',{username,password});this.token=r.tokenValue;this.applyIdentity(r);await this.refreshUnread()},
    async me(){const r:any=await request.get('/api/auth/me');this.applyIdentity(r)},
    async ensureIdentity(){if(this.token&&this.identityIncomplete())await this.me()},
    async refreshUnread(){if(!this.token)return;try{const r:any=await request.get('/api/auth/notifications/unread-count');this.unread=Number(r.count||0)}catch{}},
    logoutLocal(){this.$reset()},async logout(){try{await request.post('/api/auth/logout')}finally{this.logoutLocal()}},can(p:string){return this.permissions.includes(p)}
  }
});
