import { createApp } from "vue";
import App from "./App.vue";
import { createPinia } from "pinia";
import router from "./router";
import "vuetify/styles";
import { createVuetify } from "vuetify";
import * as components from "vuetify/components";
import * as directives from "vuetify/directives";

const vuetify = createVuetify({
  components,
  directives,
  theme: {
    defaultTheme: localStorage.getItem("theme") || "light",
    themes: {
      light: { dark: false, colors: { background: "#FFFFFF", surface: "#FFFFFF", primary: "#1976D2" } },
      dark: { dark: true, colors: { background: "#121212", surface: "#1E1E1E", primary: "#2196F3" } },
    },
  },
});

createApp(App).use(createPinia()).use(router).use(vuetify).mount("#app");