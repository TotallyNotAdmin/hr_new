<template>
<v-card>
<v-card-title class="d-flex justify-space-between align-center">
      Сотрудники
      <v-btn
        v-if="auth.isManager"
        variant="outlined"
        color="success"
        prepend-icon="mdi-file-excel"
        @click="handleExport"
        :loading="loading"
      >
        Экспорт (.xlsx)
      </v-btn>
    </v-card-title>
<v-table>
<thead>
<tr>
<th>ID</th>
<th>ФИО</th>
<th>Должность</th>
</tr>
</thead>
<tbody>
<tr v-for="e in employees" :key="e.id">
<td>{{ e.id }}</td>
<td>{{ e.full_name }}</td>
<td>{{ e.position_name || '—' }}</td>
</tr>
</tbody>
</v-table>
</v-card>
<v-snackbar v-model="snack.show" :color="snack.color" top right>{{ snack.text }}</v-snackbar>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { getEmployees, exportEmployees } from "@/api/employees";
import { useAuthStore } from "@/store/auth";

const employees = ref([]);
const auth = useAuthStore();
const loading = ref(false);
const snack = ref({ show: false, text: "", color: "error" });

onMounted(async () => {
  const res = await getEmployees();
  employees.value = res.data;
});

const handleExport = async () => {
  loading.value = true;
  try {
    const res = await exportEmployees();
    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement('a');
    link.href = url; link.setAttribute('download', 'employees.xlsx');
    document.body.appendChild(link); link.click(); link.remove();
    window.URL.revokeObjectURL(url);
  } catch (err) {
    snack.value = { show: true, text: "Ошибка экспорта", color: "error" };
  } finally { loading.value = false; }
};
</script>