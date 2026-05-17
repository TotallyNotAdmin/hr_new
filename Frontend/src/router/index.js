import { createRouter, createWebHistory } from "vue-router";
import Login from "@/views/Login.vue";
import MainLayout from "@/layouts/MainLayout.vue";
import Dashboard from "@/views/Dashboard.vue";
import Requests from "@/views/Requests.vue";
import RequestDetail from "@/views/RequestDetail.vue";
import CreateRequest from "@/views/CreateRequest.vue";
import Employees from "@/views/Employees.vue";
import Positions from "@/views/Positions.vue";

const routes = [
  { path: "/login", component: Login },
  {
    path: "/",
    component: MainLayout,
    children: [
      { path: "", component: Dashboard },
      { path: "requests", component: Requests },
      { path: "requests/:id", component: RequestDetail },
      { path: "create", component: CreateRequest },
      { path: "employees", component: Employees },
      { path: "positions", component: Positions },
      { path: "create/:id?", component: CreateRequest },
    ],
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem("token");
  if (!token && to.path !== "/login") {
    next("/login");
  } else {
    next();
  }
});

export default router;