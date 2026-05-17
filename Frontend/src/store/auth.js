import { defineStore } from "pinia";
import api from "@/api/axios";
import { jwtDecode } from "jwt-decode";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    token: localStorage.getItem("token") || null,
    role: localStorage.getItem("role") || null,
    user_id: localStorage.getItem("user_id") || null,
    userLogin: localStorage.getItem("login") || null,
  }),
  actions: {
    async login(loginInput, password) {
      const res = await api.post("/login", { login: loginInput, password });
      this.token = res.data.access_token;
      const decoded = jwtDecode(this.token);

      this.role = decoded.role;
      this.user_id = decoded.user_id;
      this.userLogin = decoded.login;

      localStorage.setItem("token", this.token);
      localStorage.setItem("role", this.role);
      localStorage.setItem("user_id", this.user_id);
      localStorage.setItem("login", this.userLogin);
    },
    logout() {
      this.token = null;
      this.role = null;
      this.user_id = null;
      this.userLogin = null;

      localStorage.removeItem("token");
      localStorage.removeItem("role");
      localStorage.removeItem("user_id");
      localStorage.removeItem("login");

      delete api.defaults.headers.common.Authorization;
    },
  },
  getters: {
    isAuthenticated: (state) => !!state.token,
    isManager: (state) => state.role === "manager",
    isApprover: (state) => state.role === "approver",
    isExecutor: (state) => state.role === "executor",
  },
});