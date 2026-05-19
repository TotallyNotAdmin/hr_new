import api from "./axios";

export const getPositions = () => api.get("/positions/");
export const exportPositions = () => api.get("/positions/export", { responseType: 'blob' });