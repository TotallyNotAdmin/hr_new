<template>
  <div>
    <h2 class="mb-4">Панель управления</h2>
    <v-row>
      <v-col cols="12" md="4">
        <v-card color="primary" variant="tonal">
          <v-card-title>Мои заявки</v-card-title>
          <v-card-text class="text-h3">{{ myRequestsCount }}</v-card-text>
          <v-card-actions><v-btn variant="text" @click="$router.push('/requests')">Посмотреть</v-btn></v-card-actions>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card color="success" variant="tonal">
          <v-card-title>Исполнено</v-card-title>
          <v-card-text class="text-h3">{{ doneCount }}</v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card color="warning" variant="tonal">
          <v-card-title>Требуют внимания</v-card-title>
          <v-card-text class="text-h3">{{ attentionCount }}</v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <h3 class="mt-8 mb-4">Последние заявки</h3>
    <v-table density="comfortable">
      <thead>
        <tr>
          <th class="cursor-pointer" @click="toggleSort('id')">
            ID <v-icon size="small" class="ml-1">{{ getSortIcon('id') }}</v-icon>
          </th>
          <th>Статус</th>
          <th class="cursor-pointer" @click="toggleSort('created_at')">
            Дата создания <v-icon size="small" class="ml-1">{{ getSortIcon('created_at') }}</v-icon>
          </th>
          <th class="cursor-pointer" @click="toggleSort('updated_at')">
            Последнее действие <v-icon size="small" class="ml-1">{{ getSortIcon('updated_at') }}</v-icon>
          </th>
          <th>Действия</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in sortedRecent" :key="r.id">
          <td>#{{ r.id }}</td>
          <td><v-chip :color="getStatusColor(r.status)" size="small">{{ translateStatus(r.status) }}</v-chip></td>
          <td>{{ formatDate(r.created_at) }}</td>
          <td>{{ formatRelativeTime(r.updated_at || r.created_at) }}</td>
          <td><v-btn size="small" variant="text" @click="$router.push(`/requests/${r.id}`)">Открыть</v-btn></td>
        </tr>
      </tbody>
    </v-table>
    <v-alert v-if="requests.length === 0" type="info" class="mt-4">У вас пока нет заявок</v-alert>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { getRequests } from "@/api/requests";
import { useAuthStore } from "@/store/auth";

const requests = ref([]);
const auth = useAuthStore();

// Сортировка
const sortKey = ref("updated_at");
const sortOrder = ref("desc");

const toggleSort = (key) => {
  if (sortKey.value === key) sortOrder.value = sortOrder.value === "asc" ? "desc" : "asc";
  else { sortKey.value = key; sortOrder.value = "desc"; }
};
const getSortIcon = (key) => {
  if (sortKey.value !== key) return "mdi-swap-vertical";
  return sortOrder.value === "asc" ? "mdi-arrow-up" : "mdi-arrow-down";
};

const sortedRecent = computed(() => {
  const list = [...requests.value].slice(0, 10); // Берём чуть больше для корректной сортировки
  return list.sort((a, b) => {
    const key = sortKey.value;
    const valA = a[key] || "";
    const valB = b[key] || "";
    if (key.includes("date")) {
      const dateA = new Date(valA).getTime();
      const dateB = new Date(valB).getTime();
      return sortOrder.value === "asc" ? dateA - dateB : dateB - dateA;
    }
    return sortOrder.value === "asc" ? String(valA).localeCompare(valB) : String(valB).localeCompare(valA);
  }).slice(0, 5);
});

const myRequestsCount = computed(() => requests.value.length);
const doneCount = computed(() => requests.value.filter(r => r.status === 'DONE').length);
const attentionCount = computed(() => requests.value.filter(r => {
  if (auth.isManager) return r.status === 'RETURNED';
  if (auth.isApprover) return r.status === 'ON_APPROVAL';
  if (auth.isExecutor) return r.status === 'APPROVED';
  return false;
}).length);

const getStatusColor = (status) => ({ DRAFT: "grey", ON_APPROVAL: "orange", APPROVED: "green", IN_PROGRESS: "blue", DONE: "purple", RETURNED: "amber", REJECTED: "red" }[status] || "grey");
const translateStatus = (status) => ({ DRAFT: "Черновик", ON_APPROVAL: "На согласовании", APPROVED: "Согласовано", IN_PROGRESS: "В работе", DONE: "Исполнено", RETURNED: "На доработку", REJECTED: "Отклонено" }[status] || status);

const formatDate = (date) => date ? new Date(date).toLocaleDateString("ru-RU") : "—";

const formatRelativeTime = (dateStr) => {
  if (!dateStr) return "—";
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now - date;
  if (diffMs < 0) return formatDate(dateStr); // Защита от будущих дат
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffDays > 7) return formatDate(dateStr);
  if (diffDays > 0) return `${diffDays} дн. назад`;
  if (diffHours > 0) return `${diffHours} ч. назад`;
  return `${diffMins} мин. назад`;
};

const load = async () => {
  try { const res = await getRequests(); requests.value = res.data; } 
  catch (error) { console.error("Ошибка загрузки:", error); }
};
onMounted(load);
</script>