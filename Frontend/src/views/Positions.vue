<template>
<v-card>
<v-card-title class="d-flex justify-space-between align-center">
      Штатные единицы
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
<th>Системное имя</th>
<th>Наименование</th>
<th>Оклад (руб.)</th>
</tr>
</thead>
<tbody>
<tr v-for="p in positions" :key="p.id">
<td>{{ p.id }}</td>
<td>{{ p.system_name || '—' }}</td>
<td>{{ p.position_name }}</td>
<td>{{ p.salary }}</td>
</tr>
</tbody>
</v-table>
</v-card>
<v-snackbar v-model="snack.show" :color="snack.color" top right>{{ snack.text }}</v-snackbar>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { getPositions, exportPositions } from "@/api/positions";
import { useAuthStore } from "@/store/auth";

const positions = ref([]);
const auth = useAuthStore();
const loading = ref(false);
const snack = ref({ show: false, text: "", color: "error" });

onMounted(async () => {
  const res = await getPositions();
  positions.value = res.data;
});

const handleExport = async () => {
  loading.value = true;
  try {
    const res = await exportPositions();
    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement('a');
    link.href = url; link.setAttribute('download', 'positions.xlsx');
    document.body.appendChild(link); link.click(); link.remove();
    window.URL.revokeObjectURL(url);
  } catch (err) {
    snack.value = { show: true, text: "Ошибка экспорта", color: "error" };
  } finally { loading.value = false; }
};
</script>