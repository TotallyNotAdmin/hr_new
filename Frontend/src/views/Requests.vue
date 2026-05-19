<template>
  <!-- Панель управления -->
  <div class="d-flex flex-wrap justify-space-between align-center mb-4" style="gap:12px;">
    <h2 class="text-h5 mb-0">Заявки</h2>
    <div class="d-flex flex-wrap align-center" style="gap:12px;">
      <v-select v-model="sortBy" :items="sortOptions" item-title="label" item-value="value" label="Сортировка" density="compact" hide-details style="max-width:220px;" prepend-inner-icon="mdi-sort"/>
      <v-btn-toggle v-model="viewMode" mandatory density="compact" class="v-btn-group" style="border:1px solid rgba(0,0,0,0.12);border-radius:4px;">
        <v-btn value="all" size="small">Все</v-btn>
        <v-btn value="active" size="small">Только активные</v-btn>
      </v-btn-toggle>
      <v-btn v-if="auth.isManager" color="primary" prepend-icon="mdi-plus" @click="$router.push('/create')">Создать заявку</v-btn>
    </div>
  </div>

  <template v-for="section in sections" :key="section.key">
    <div v-if="section.show" class="mb-6">
      <div class="d-flex align-center mb-2">
        <v-chip :color="section.color" size="small" class="font-weight-bold">{{ section.title }} ({{ section.requests.length }})</v-chip>
        <v-spacer/>
        <v-btn v-if="section.hideable" variant="text" size="small" @click="section.toggleHide()" :prepend-icon="section.isHidden ? 'mdi-eye' : 'mdi-eye-off'">
          {{ section.isHidden ? 'Показать' : 'Скрыть' }}
        </v-btn>
      </div>
      <v-row v-show="!section.isHidden">
        <v-col v-for="r in section.requests" :key="r.id" cols="12" md="4">
          <v-card class="d-flex flex-column" style="height: 100%">
            <v-card-title class="d-flex justify-space-between">
              <span>#{{ r.id }}<span v-if="r.manager_comment" class="text-medium-emphasis text-body-2 ml-1">: {{ r.manager_comment }}</span></span>
              <v-chip :color="getStatusColor(r.status)" size="small">{{ translateStatus(r.status) }}</v-chip>
            </v-card-title>
            <v-card-subtitle class="d-flex flex-column">
              <span>Создана: {{ formatDate(r.created_at) }}</span>
              <span v-if="isUpdated(r)" class="text-caption text-medium-emphasis">Изменена: {{ formatDate(r.updated_at) }}</span>
            </v-card-subtitle>
            
            <v-card-actions class="mt-auto">
              <v-btn variant="text" @click="router.push(`/requests/${r.id}`)">Подробнее</v-btn>
              <!-- Редактирование (manager) -->
              <v-btn v-if="auth.isManager && section.cardConfig.showEdit && (r.status==='DRAFT'||r.status==='RETURNED')"
                color="secondary" size="small" @click="router.push(`/create/${r.id}`)" title="Редактировать">✏️</v-btn>
              <!-- Согласование (approver) -->
              <template v-if="section.cardConfig.showApproval && r.status==='ON_APPROVAL'">
                <v-btn color="success" size="small" @click="handleCardAction('approve', r.id)" title="Согласовать">✓</v-btn>
                <v-btn color="warning" size="small" @click="handleCardAction('return', r.id)" title="На доработку">↩</v-btn>
                <v-btn color="error" size="small" @click="handleCardAction('reject', r.id)" title="Отклонить">✗</v-btn>
              </template>
              <!-- Исполнитель -->
              <template v-if="section.cardConfig.showExecutor">
                <v-btn v-if="r.status==='APPROVED'" color="primary" size="small" @click="handleCardAction('take', r.id)">Взять</v-btn>
                <v-btn v-if="r.status==='IN_PROGRESS'" color="success" size="small" @click="handleCardAction('complete', r.id)">✓</v-btn>
              </template>
            </v-card-actions>
          </v-card>
        </v-col>
      </v-row>
    </div>
  </template>

  <v-alert v-if="!requests.length" type="info" class="mt-4">У вас пока нет заявок</v-alert>

  <v-dialog v-model="dialog" max-width="500">
    <v-card>
      <v-card-title>{{ dialogTitle }}</v-card-title>
      <v-card-text>
        <v-textarea v-model="comment" label="Комментарий" rows="4" placeholder="Укажите причину..."/>
      </v-card-text>
      <v-card-actions>
        <v-btn variant="text" @click="dialog=false">Отмена</v-btn>
        <v-btn :color="dialogColor" @click="confirmAction">Подтвердить</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-snackbar v-model="snack.show" :color="snack.color" top right>{{ snack.text }}</v-snackbar>
  <v-dialog v-model="confirmDialog.show" max-width="400">
    <v-card>
      <v-card-title class="text-h5">{{ confirmDialog.title }}</v-card-title>
      <v-card-text>{{ confirmDialog.text }}</v-card-text>
      <v-card-actions>
        <v-btn variant="text" @click="confirmDialog.resolve?.(false); confirmDialog.show=false">Отмена</v-btn>
        <v-btn :color="confirmDialog.color" @click="confirmDialog.resolve?.(true); confirmDialog.show=false">Подтвердить</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/store/auth";
import { getRequests, approveRequest, rejectRequest, returnRequest, takeRequest, completeRequest } from "@/api/requests";

// === Основные данные и состояние ===
const router = useRouter();
const auth = useAuthStore();
const requests = ref([]);
const dialog = ref(false);
const dialogTitle = ref("");
const dialogColor = ref("primary");
const comment = ref("");
const pendingAction = ref(null);
const pendingId = ref(null);
const snack = ref({ show: false, text: "", color: "error" });
const confirmDialog = ref({ show: false, title: "", text: "", color: "primary", resolve: null });
const sortBy = ref("updated_at");
const viewMode = ref("all");
const hideDrafts = ref(false);
const hideArchived = ref(false);
const sortOptions = [
  { label: "По последнему изменению", value: "updated_at" },
  { label: "По дате создания", value: "created_at" },
  { label: "По статусу", value: "status" },
];

const statusPriorityMap = {
  manager:  { RETURNED: 1, ON_APPROVAL: 2, APPROVED: 3, IN_PROGRESS: 4, DRAFT: 5, DONE: 6, REJECTED: 7 },
  approver: { ON_APPROVAL: 1, RETURNED: 2, APPROVED: 3, IN_PROGRESS: 4, DRAFT: 5, DONE: 6, REJECTED: 7 },
  executor: { APPROVED: 1, IN_PROGRESS: 2, ON_APPROVAL: 3, DRAFT: 4, RETURNED: 5, DONE: 6, REJECTED: 7 }
};

const getRoleKey = () => auth.isManager ? 'manager' : auth.isApprover ? 'approver' : 'executor';
const getStatusPriority = (status) => statusPriorityMap[getRoleKey()][status] ?? 99;

const sortRequests = arr => [...arr].sort((a, b) => {
  if (sortBy.value === 'status') {
    return getStatusPriority(a.status) - getStatusPriority(b.status);
  }
  const val = r => sortBy.value === 'updated_at' ? new Date(r.updated_at || r.created_at) : new Date(r.created_at);
  return val(b) - val(a);
});

// === Утилиты ===
const getStatusColor = s => ({DRAFT:"grey",ON_APPROVAL:"orange",APPROVED:"green",IN_PROGRESS:"blue",DONE:"purple",RETURNED:"amber",REJECTED:"red"}[s]||"grey");
const translateStatus = s => ({DRAFT:"Черновик",ON_APPROVAL:"На согласовании",APPROVED:"Согласовано",IN_PROGRESS:"В работе",DONE:"Исполнено",RETURNED:"На доработку",REJECTED:"Отклонено"}[s]||s);
const formatDate = d => d ? new Date(d).toLocaleDateString("ru-RU",{day:"2-digit",month:"2-digit",year:"numeric",hour:"2-digit",minute:"2-digit"}) : "—";
const isUpdated = r => r.updated_at && r.created_at && new Date(r.updated_at) > new Date(r.created_at);

// === Группировка заявок ===
const drafts = computed(() => sortRequests(requests.value.filter(r => r.status === "DRAFT")));
const archived = computed(() => sortRequests(requests.value.filter(r => ["DONE","REJECTED"].includes(r.status))));
const active = computed(() => sortRequests(requests.value.filter(r => !["DRAFT","DONE","REJECTED"].includes(r.status))));

const sections = computed(() => [
  {
    key: 'drafts',
    show: viewMode.value !== 'active' && drafts.value.length > 0,
    isHidden: hideDrafts.value,
    title: 'Черновики',
    color: 'grey',
    hideable: true,
    toggleHide: () => hideDrafts.value = !hideDrafts.value,
    requests: drafts.value,
    cardConfig: { showEdit: true, showApproval: false, showExecutor: false }
  },
  {
    key: 'active',
    show: true,
    isHidden: false,
    title: 'Активные заявки',
    color: 'primary',
    hideable: false,
    toggleHide: () => {},
    requests: active.value,
    cardConfig: { showEdit: true, showApproval: auth.isApprover, showExecutor: auth.isExecutor }
  },
  {
    key: 'archived',
    show: viewMode.value !== 'active' && archived.value.length > 0,
    isHidden: hideArchived.value,
    title: 'Завершённые',
    color: 'blue-grey',
    hideable: true,
    toggleHide: () => hideArchived.value = !hideArchived.value,
    requests: archived.value,
    cardConfig: { showEdit: false, showApproval: false, showExecutor: false }
  }
]);

// === Диалоги и действия ===
const showConfirm = (title, text, color = "primary") => new Promise(resolve => {
  confirmDialog.value = { show: true, title, text, color, resolve: v => { confirmDialog.value.show = false; resolve(v); } };
});
const openActionDialog = (title, color, action, id) => {
  dialogTitle.value = title; dialogColor.value = color; pendingAction.value = action; pendingId.value = id; comment.value = ""; dialog.value = true;
};
const confirmAction = async () => {
  if (!comment.value.trim()) { snack.value = { show: true, text: "Введите комментарий", color: "warning" }; return; }
  dialog.value = false;
  const api = pendingAction.value === 'return' ? returnRequest : rejectRequest;
  await api(pendingId.value, comment.value);
  load();
};
const handleCardAction = async (type, id) => {
  try {
    if (type === 'approve' && !await showConfirm("Согласовать заявку?", "Вы уверены?", "success")) return;
    if (type === 'complete' && !await showConfirm("Завершить заявку?", "Заявка будет помечена как исполнена", "success")) return;
    const actions = { approve: approveRequest, take: takeRequest, complete: completeRequest };
    if (actions[type]) { await actions[type](id); }
    else if (['return','reject'].includes(type)) {
      openActionDialog(type==='return' ? "Отправить на доработку" : "Отклонить заявку", type==='return' ? "warning" : "error", type, id);
      return;
    }
    load();
  } catch {
    snack.value = { show: true, text: "Ошибка выполнения действия", color: "error" };
  }
};
const load = async () => {
  try { requests.value = (await getRequests()).data; }
  catch { snack.value = { show: true, text: "Ошибка загрузки заявок", color: "error" }; }
};
onMounted(load);
</script>