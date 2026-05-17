import api from "./axios";
export const getRequests = () => api.get("/requests");
export const createRequest = (data) => api.post("/requests", data);
export const updateRequest = (id, data) => api.put(`/requests/${id}`, data);
export const submitRequest = (id) => api.post(`/requests/${id}/submit`);
export const approveRequest = (id) => api.post(`/requests/${id}/approve`);
export const rejectRequest = (id, comment) =>
api.post(`/requests/${id}/reject?comment=${encodeURIComponent(comment)}`);
export const returnRequest = (id, comment) =>
api.post(`/requests/${id}/return?comment=${encodeURIComponent(comment)}`);
export const takeRequest = (id) => api.post(`/requests/${id}/take`);
export const completeRequest = (id) => api.post(`/requests/${id}/complete`);
export const exportRequest = (id, format) => 
  api.get(`/requests/${id}/export?format=${format}`, { responseType: 'blob' });
export const deleteRequest = (id) => api.delete(`/requests/${id}`);