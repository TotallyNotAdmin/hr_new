<template>
  <v-card>
    <v-card-title class="d-flex justify-space-between align-center">
        <span>
            Заявка #{{ request?.id }}
            <span v-if="request?.manager_comment" class="text-medium-emphasis text-body-1 ml-2">
                {{ request?.manager_comment }}
            </span>
        </span>
        <v-chip :color="getStatusColor(request?.status)" size="large">
            {{ translateStatus(request?.status) }}
        </v-chip>
    </v-card-title>
    <v-card-subtitle>
      Создана: {{ formatDate(request?.created_at) }} |
      Сценарий: {{ getScenarioName(request?.scenario_type) }}
    </v-card-subtitle>
    
    <v-divider class="my-4" />
    
    <!-- Комментарий, если есть -->
    <v-alert
      v-if="request?.history_comment"
      :type="request?.last_action === 'reject' ? 'error' : 'warning'"
      variant="tonal"
      class="mb-4"
    >
      <strong>{{ request?.last_action === 'reject' ? 'Причина отклонения:' : 'Комментарий:' }}</strong>
      {{ request?.history_comment }}
    </v-alert>

    <v-card-text v-if="request?.description" class="mb-4">
      <h4 class="mb-2 text-body-1 font-weight-medium">Подробное описание</h4>
      <v-card variant="outlined" class="pa-3 bg-grey-lighten-5" style="white-space: pre-wrap;">
        {{ request.description }}
      </v-card>
    </v-card-text>

    <!-- Поля заявки -->
    <v-card-text v-if="fields.length > 0">
      <h4 class="mb-3">Данные заявки</h4>
      <v-table density="compact">
        <thead>
          <tr>
            <th>Поле</th>
            <th>Было (AS IS)</th>
            <th>Станет (TO BE)</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="field in fields" :key="field.field_name">
            <td>{{ translateFieldName(field.field_name) }}</td>
            <td>{{ resolveFieldValue(field, 'as_is') }}</td>
            <td>{{ resolveFieldValue(field, 'to_be') }}</td>
          </tr>
        </tbody>
      </v-table>
    </v-card-text>
    
    <!-- История действий -->
    <v-card-text v-if="history.length > 0">
      <h4 class="mb-3 mt-6">История действий</h4>
      <v-timeline density="compact">
      <v-timeline-item
          v-for="h in history"
          :key="h.id"
          :color="getHistoryColor(h.action)"
          size="small"
      >
          <strong>{{ formatDate(h.created_at) }}</strong>
          <div>{{ getActionText(h.action) }}</div>
          <!-- Показываем, кто сделал действие -->
          <div class="text-secondary text-caption">
            {{ h.full_name }} ({{ translateRole(h.role) }})
          </div>
          <div v-if="h.comment" class="text-secondary text-caption">
            {{ h.comment }}
          </div>
      </v-timeline-item>
      </v-timeline>
    </v-card-text>
    
    <v-divider class="my-4" />
    
    <!-- Кнопки действий -->
    <v-card-actions class="justify-space-between align-center pa-3">
      <!-- ЛЕВЫЙ БЛОК: Экспорт -->
      <div>
        <v-menu v-if="request?.status && request.status !== 'DRAFT'">
          <template v-slot:activator="{ props }">
            <v-btn variant="outlined" prepend-icon="mdi-export" v-bind="props">
              Экспорт
              <v-icon end size="small">mdi-chevron-down</v-icon>
            </v-btn>
          </template>
          <v-list density="compact">
            <v-list-item @click="handleExport('xlsx')" prepend-icon="mdi-file-excel">
              Сохранить как Excel (.xlsx)
            </v-list-item>
            <v-list-item @click="handleExport('docx')" prepend-icon="mdi-file-word">
              Сохранить как Word (.docx)
            </v-list-item>
          </v-list>
        </v-menu>
      </div>

      <!-- ПРАВЫЙ БЛОК: Навигация и Действия -->
      <div class="d-flex flex-wrap" style="gap: 8px;">
        <v-btn variant="text" @click="$router.back()">Назад</v-btn>

        <v-btn v-if="auth.isManager && ['DRAFT', 'RETURNED'].includes(request?.status)"
               color="secondary" variant="text" 
               @click="$router.push(`/create/${request.id}`)" 
               prepend-icon="mdi-pencil">
            Редактировать
        </v-btn>

        <template v-if="auth.isManager && canDelete">
          <v-btn color="error" variant="text" @click="confirmDelete" prepend-icon="mdi-delete">Удалить</v-btn>
        </template>
        
        <template v-if="auth.isManager && request?.status === 'DRAFT'">
          <v-btn color="primary" @click="submit">Отправить на согласование</v-btn>
        </template>
        
        <template v-if="auth.isApprover && request?.status === 'ON_APPROVAL'">
          <v-btn color="warning" @click="showReturnDialog">На доработку</v-btn>
          <v-btn color="error" @click="showRejectDialog">Отклонить</v-btn>
          <v-btn color="success" @click="approve">Согласовать</v-btn>
        </template>
        
        <template v-if="auth.isExecutor">
          <v-btn v-if="request?.status === 'APPROVED'" color="primary" @click="take">Взять в работу</v-btn>
          <v-btn v-if="request?.status === 'IN_PROGRESS'" color="success" @click="complete">Завершить</v-btn>
          <v-btn v-if="['APPROVED', 'IN_PROGRESS'].includes(request?.status)" color="warning" @click="showReturnDialog">На доработку</v-btn>
          <v-btn v-if="['APPROVED', 'IN_PROGRESS'].includes(request?.status)" color="error" @click="showRejectDialog">Отклонить</v-btn>
        </template>
      </div>
    </v-card-actions>
  </v-card>
  
  <!-- Диалог для комментария -->
  <v-dialog v-model="dialog" max-width="500">
    <v-card>
      <v-card-title>{{ dialogTitle }}</v-card-title>
      <v-card-text>
        <v-textarea
          v-model="comment"
          label="Комментарий"
          rows="4"
          placeholder="Введите комментарий..."
        />
      </v-card-text>
      <v-card-actions>
        <v-btn variant="text" @click="dialog = false">Отмена</v-btn>
        <v-btn :color="dialogColor" @click="confirmAction">Подтвердить</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-snackbar v-model="snack.show" :color="snack.color" top right>{{ snack.text }}</v-snackbar>
  <v-dialog v-model="confirm.show" max-width="400">
    <v-card>
      <v-card-title class="text-h5">{{ confirm.title }}</v-card-title>
      <v-card-text>{{ confirm.text }}</v-card-text>
      <v-card-actions>
        <v-btn variant="text" @click="() => { confirm.show = false; confirm.resolve?.(false) }">Отмена</v-btn>
        <v-btn :color="confirm.color" @click="() => { confirm.show = false; confirm.resolve?.(true) }">Подтвердить</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup>
import { ref, onMounted, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore } from "@/store/auth";
import { exportRequest } from "@/api/requests";
import { getEmployees } from "@/api/employees";
import { getPositions } from "@/api/positions";
import api from "@/api/axios";
import {
  approveRequest,
  rejectRequest,
  returnRequest,
  takeRequest,
  completeRequest,
  submitRequest,
  deleteRequest,
} from "@/api/requests";

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const request = ref(null);
const fields = ref([]);
const history = ref([]);
const employees = ref([]);
const positions = ref([]);
const dialog = ref(false);
const dialogTitle = ref("");
const dialogColor = ref("primary");
const comment = ref("");
const pendingAction = ref(null);
const snack = ref({ show: false, text: "", color: "error" });
const confirm = ref({ show: false, title: "", text: "", color: "primary", resolve: () => {} });

const showConfirm = (title, text, color = "primary") => {
  return new Promise((resolve) => {
    confirm.value = { 
      show: true, 
      title, 
      text, 
      color, 
      resolve: (val) => {
        confirm.value.show = false;
        resolve(val);
      }
    };
  });
};

const load = async () => {
  try {
    const [reqRes, fieldsRes, histRes, empRes, posRes] = await Promise.all([
      api.get(`/requests/${route.params.id}`),
      api.get(`/requests/${route.params.id}/fields`),
      api.get(`/requests/${route.params.id}/history`),
      getEmployees(),
      getPositions()
    ]);
    request.value = reqRes.data;
    fields.value = fieldsRes.data;
    history.value = histRes.data;
    employees.value = empRes.data;
    positions.value = posRes.data;
  } catch (error) {
    console.error("Ошибка загрузки заявки:", error);
    snack.value = { show: true, text: "Не удалось загрузить заявку", color: "error" };
    router.back();
  }
};

const resolveFieldValue = (field, type) => {
  const val = type === 'as_is' ? field.as_is_value : field.to_be_value;
  if (!val || val === '0' || val === '') return '—';
  
  if (field.field_name === 'employee_id') {
    const emp = employees.value.find(e => e.id === parseInt(val));
    return emp ? emp.full_name : val;
  }
  if (field.field_name === 'position_id') {
    const pos = positions.value.find(p => p.id === parseInt(val));
    return pos ? pos.position_name : val;
  }
  if (['bonus_month', 'bonus_quarter', 'bonus_year'].includes(field.field_name)) {
    return `${val}%`;
  }
  return val;
};

const submit = async () => {
  if (!await showConfirm("Отправить на согласование?", "После отправки заявка станет недоступна для редактирования!", "primary")) return;
  await submitRequest(request.value.id);
  router.push("/requests");
};

const approve = async () => {
  if (!await showConfirm("Согласовать заявку?", "Вы уверены?", "success")) return;
  await approveRequest(request.value.id);
  router.push("/requests");
};

const showReturnDialog = () => {
  dialogTitle.value = "Отправить на доработку";
  dialogColor.value = "warning";
  pendingAction.value = "return";
  comment.value = "";
  dialog.value = true;
};

const showRejectDialog = () => {
  dialogTitle.value = "Отклонить заявку";
  dialogColor.value = "error";
  pendingAction.value = "reject";
  comment.value = "";
  dialog.value = true;
};

const confirmAction = async () => {
  if (!comment.value.trim()) {
    snack.value = { show: true, text: "Введите комментарий", color: "warning" };
    return;
  }
  dialog.value = false;
  if (pendingAction.value === "return") await returnRequest(request.value.id, comment.value);
  else if (pendingAction.value === "reject") await rejectRequest(request.value.id, comment.value);
  router.push("/requests");
};

const take = async () => {
  await takeRequest(request.value.id);
  router.push("/requests");
};

const complete = async () => {
  if (!await showConfirm("Завершить заявку?", "Заявка будет переведена в статус 'Исполнено'", "success")) return;
  await completeRequest(request.value.id);
  router.push("/requests");
};

const getStatusColor = (status) => {
  return {
    DRAFT: "grey",
    ON_APPROVAL: "orange",
    APPROVED: "green",
    IN_PROGRESS: "blue",
    DONE: "purple",
    RETURNED: "amber",
    REJECTED: "red",
  }[status] || "grey";
};

const translateStatus = (status) => {
  return {
    DRAFT: "Черновик",
    ON_APPROVAL: "На согласовании",
    APPROVED: "Согласовано",
    IN_PROGRESS: "В работе",
    DONE: "Исполнено",
    RETURNED: "На доработке",
    REJECTED: "Отклонено",
  }[status] || status;
};

const getScenarioName = (type) => {
  return {
    1: "Перевод сотрудника",
    2: "Ввод новой ставки",
    3: "Вывод существующей ставки",
    4: "Изменение условий",
  }[type] || `Сценарий ${type}`;
};

const translateFieldName = (name) => {
  return {
    employee_id: "Сотрудник",
    position_id: "Штатная единица",
    position_name: "Должность",
    salary: "Оклад",
    address: "Адрес",
    headcount: "Количество ставок",
    bonus_month: "Премия (месяц)",
    bonus_quarter: "Премия (квартал)",
    bonus_year: "Премия (год)",
    date: "Дата",
  }[name] || name;
};

const formatDate = (date) => {
  if (!date) return "—";
  return new Date(date).toLocaleDateString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

const getHistoryColor = (action) => {
  return {
    submit: "blue",
    approve: "green",
    return: "amber",
    reject: "red",
    take: "purple",
    complete: "success",
  }[action] || "grey";
};

const getActionText = (action) => {
  return {
    submit: "Отправлено на согласование",
    approve: "Согласовано",
    return: "Отправлено на доработку",
    reject: "Отклонено",
    take: "Взято в работу",
    complete: "Завершено",
  }[action] || action;
};

const translateRole = (role) => {
    return {
        manager: "Руководитель",
        approver: "Согласующий",
        executor: "Исполнитель",
    }[role] || role;
};

const getFieldValue = (field) => {
const name = field.field_name;
const asIs = field.as_is_value;
const toBe = field.to_be_value;

// Для employee_id и position_id нужно получить имена
if (name === 'employee_id' && asIs) {
const employee = employees.value.find(e => e.id === parseInt(asIs));
return employee ? employee.full_name : asIs;
}
if (name === 'position_id' && asIs) {
const position = positions.value.find(p => p.id === parseInt(asIs));
return position ? position.position_name : asIs;
}
if (name === 'position_id' && toBe) {
const position = positions.value.find(p => p.id === parseInt(toBe));
return position ? position.position_name : toBe;
}

// Для бонусов - проверять на null/undefined и пустую строку
if (['bonus_month', 'bonus_quarter', 'bonus_year'].includes(name)) {
const formatBonus = (val) => {
if (val === null || val === undefined || val === '' || val === '0') return '—';
return `${val}%`;
};
if (asIs !== null && asIs !== undefined && asIs !== '') {
return formatBonus(asIs);
}
if (toBe !== null && toBe !== undefined && toBe !== '') {
return formatBonus(toBe);
}
return '—';
}

return asIs || toBe || '—';
};

onMounted(load);

const handleExport = async (format) => {
  try {
    const res = await exportRequest(route.params.id, format);
    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `Заявка_${route.params.id}.${format}`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  } catch (err) {
    console.error("Ошибка экспорта:", err);
    snack.value = { 
      show: true, 
      text: err.response?.data?.detail || "Не удалось сформировать файл", 
      color: "error" 
    };
  }
};

const canDelete = computed(() => {
  return auth.isManager && 
         request.value?.status === 'DRAFT' && 
         !history.value.some(h => h.action === 'submit');
});

const confirmDelete = async () => {
  if (!await showConfirm("Удалить заявку?", "Черновик будет удалён безвозвратно. Продолжить?", "error")) return;
  try {
    await deleteRequest(request.value.id);
    router.push("/requests");
  } catch (err) {
    snack.value = { show: true, text: err.response?.data?.detail || "Ошибка удаления", color: "error" };
  }
};
</script>