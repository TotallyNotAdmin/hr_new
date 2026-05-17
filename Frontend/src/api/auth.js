import api from "./axios";
export const changePassword = (data) => api.post("/change-password", data);