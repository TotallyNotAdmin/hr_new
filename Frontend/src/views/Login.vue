<template>
  <v-container class="fill-height d-flex flex-column align-center justify-center pa-10">
    <!-- Карточка авторизации -->
    <v-card width="400" elevation="4" class="mb-6">
      <v-card-title class="text-center">Авторизация</v-card-title>
      <v-card-text>
        <v-form @submit.prevent="submit">
          <v-text-field v-model="loginInput" label="Логин" prepend-icon="mdi-account" @keyup.enter="submit" />
          <v-text-field v-model="passwordInput" label="Пароль" type="password" prepend-icon="mdi-lock" @keyup.enter="submit" />
        </v-form>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" block @click="submit" :loading="loading">Войти</v-btn>
      </v-card-actions>
    </v-card>

    <!-- Кнопка темы -->
    <v-btn icon @click="toggleTheme">
      <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
    </v-btn>

    <v-snackbar v-model="snack.show" :color="snack.color" top right timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useAuthStore } from "@/store/auth";
import { useRouter } from "vue-router";
import { useTheme } from "vuetify";

const loginInput = ref("");
const passwordInput = ref("");
const loading = ref(false);
const snack = ref({ show: false, text: "", color: "error" });
const auth = useAuthStore();
const router = useRouter();
const theme = useTheme();
const isDark = computed(() => theme.name.value === "dark");
const toggleTheme = () => {
  const newTheme = isDark.value ? "light" : "dark";
  theme.name.value = newTheme;
  localStorage.setItem("theme", newTheme);
};

onMounted(() => {
  const saved = localStorage.getItem("theme");
  if (saved) theme.name.value = saved;
});

const submit = async () => {
  if (!loginInput.value || !passwordInput.value) {
    snack.value = { show: true, text: "Введите логин и пароль!", color: "warning" };
    return;
  }
  
  loading.value = true;
  try {
    await auth.login(loginInput.value, passwordInput.value);
    router.push("/");
  } catch (err) {
    console.error("Login error:", err);
    snack.value = { 
      show: true, 
      text: err.response?.data?.detail || "Ошибка авторизации! Проверьте логин и пароль", 
      color: "error" 
    };
  } finally {
    loading.value = false;
  }
};
</script>