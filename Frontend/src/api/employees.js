import api from "./axios";

export const getEmployees = () => api.get("/employees/");
export const exportEmployees = () => api.get("/employees/export", { responseType: 'blob' });