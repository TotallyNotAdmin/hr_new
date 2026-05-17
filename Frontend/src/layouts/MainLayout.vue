<template>
  <v-app>
    <v-app-bar color="primary" dark>
      <v-toolbar-title>Штат-Контроль</v-toolbar-title>
      <v-spacer />
      
      <v-btn icon @click="toggleTheme" class="mr-2">
        <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
      </v-btn>

      <v-menu location="bottom end">
        <template v-slot:activator="{ props }">
          <v-btn variant="plain" color="white" class="mr-2" v-bind="props">
            <v-icon start>mdi-account-circle</v-icon>
            {{ auth.userLogin || 'Пользователь' }}
            <v-icon end size="small">mdi-chevron-down</v-icon>
          </v-btn>
        </template>
        <v-list min-width="220">
          <v-list-item href="mailto:support@rt.ru" prepend-icon="mdi-headset">
            <v-list-item-title>Поддержка</v-list-item-title>
          </v-list-item>
          <v-list-item @click="showPasswordDialog = true" prepend-icon="mdi-lock-reset">
            <v-list-item-title>Сменить пароль</v-list-item-title>
          </v-list-item>
          <v-divider />
          <v-list-item @click="logout" prepend-icon="mdi-logout">
            <v-list-item-title>Выйти</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </v-app-bar>

    <v-navigation-drawer app>
      <v-list>
        <v-list-item to="/" prepend-icon="mdi-home"><v-list-item-title>Главная</v-list-item-title></v-list-item>
        <v-list-item to="/requests" prepend-icon="mdi-file-document"><v-list-item-title>Заявки</v-list-item-title></v-list-item>
        <v-list-item to="/employees" prepend-icon="mdi-account-group"><v-list-item-title>Сотрудники</v-list-item-title></v-list-item>
        <v-list-item to="/positions" prepend-icon="mdi-briefcase"><v-list-item-title>Штатные единицы</v-list-item-title></v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main>
      <v-container><router-view /></v-container>
    </v-main>

    <v-dialog v-model="showPasswordDialog" max-width="400" persistent>
      <v-card>
        <v-card-title>Смена пароля</v-card-title>
        <v-card-text>
          <v-alert v-if="passwordError" type="error" variant="tonal" class="mb-3" density="compact">
            {{ passwordError }}
          </v-alert>
          <v-form @submit.prevent="handlePasswordChange">
            <v-text-field v-model="form.current" label="Текущий пароль" type="password" prepend-icon="mdi-lock" required />
            <v-text-field v-model="form.new" label="Новый пароль" type="password" prepend-icon="mdi-key" required />
            <v-text-field v-model="form.confirm" label="Повторите новый пароль" type="password" prepend-icon="mdi-key-check" required />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="closePasswordDialog">Отмена</v-btn>
          <v-btn color="primary" @click="handlePasswordChange" :loading="loading">Сохранить</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <v-snackbar v-model="passwordSnack.show" :color="passwordSnack.color" top right>
      {{ passwordSnack.text }}
    </v-snackbar>
  </v-app>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useAuthStore } from "@/store/auth";
import { useRouter } from "vue-router";
import { useTheme } from "vuetify";
import { changePassword } from "@/api/auth";

const auth = useAuthStore();
const router = useRouter();
const theme = useTheme();

// Логика темы
const isDark = computed(() => theme.global.current.value.dark);
const toggleTheme = () => {
  const newTheme = isDark.value ? "light" : "dark";
  theme.global.name.value = newTheme;
  localStorage.setItem("theme", newTheme);
};

// Логика выхода
const logout = () => {
  auth.logout();
  router.push("/login");
};

// Логика смены парол
const showPasswordDialog = ref(false);
const loading = ref(false);
const passwordError = ref("");
const form = ref({ current: "", new: "", confirm: "" });
const passwordSnack = ref({ show: false, text: "", color: "success" });

const closePasswordDialog = () => {
  showPasswordDialog.value = false;
  form.value = { current: "", new: "", confirm: "" };
  passwordError.value = "";
};

const handlePasswordChange = async () => {
  passwordError.value = "";
  if (!form.value.current || !form.value.new || !form.value.confirm) {
    passwordError.value = "Заполните все поля";
    return;
  }
  if (form.value.new !== form.value.confirm) {
    passwordError.value = "Пароли не совпадают";
    return;
  }
  if (form.value.current === form.value.new) {
    passwordError.value = "Новый пароль не должен совпадать с текущим";
    return;
  }

  loading.value = true;
  try {
    await changePassword({
      current_password: form.value.current,
      new_password: form.value.new,
    });
    closePasswordDialog();
    // Выводим сообщение об успехе
    passwordSnack.value = { show: true, text: "Пароль успешно изменён!", color: "success" };
  } catch (err) {
    console.error("Ошибка смены пароля:", err);
    passwordError.value = err.response?.data?.detail || "Ошибка при смене пароля";
  } finally {
    loading.value = false;
  }
};
</script>