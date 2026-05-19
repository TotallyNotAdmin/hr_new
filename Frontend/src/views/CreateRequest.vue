<template>
  <v-card>
    <v-card-title>{{ isEditMode ? 'Редактирование заявки' : 'Создание заявки' }}</v-card-title>
    <v-card-text>
      <v-text-field
        v-model="form.comment"
        label="Краткий комментарий к заявке (отобразится в заголовке)"
        prepend-icon="mdi-comment-text"
        placeholder="Например: Ввод новой ШЕ, Изменение оклада..."
        clearable
        class="mb-2"
      />
      <v-textarea
        v-model="form.description"
        label="Подробное описание заявки"
        placeholder="Детали изменений, обоснование, ссылки на документы..."
        rows="3"
        clearable
        class="mb-4"
      />

      <v-divider class="my-4" />
      <v-select
        v-model="scenario"
        :items="scenarios"
        item-title="name"
        item-value="id"
        label="Тип сценария"
        prepend-icon="mdi-file-document-outline"
        @update:modelValue="onScenarioChange"
        :disabled="isEditMode"
      />
      <v-divider class="my-4" />

      <div v-if="scenario === 1">
        <h4 class="mb-3">Перевод сотрудника на существующую штатную единицу</h4>
        <v-row>
          <v-col cols="12" md="6">
            <h5 class="text-primary mb-2">Текущее состояние (AS IS)</h5>
            <v-select v-model="form.employee_id" :items="employees" item-title="full_name" item-value="id" label="Сотрудник" prepend-icon="mdi-account" @update:modelValue="loadEmployeeData" />
            <v-text-field v-model="form.as_is_address" label="Адрес штатной единицы" readonly prepend-icon="mdi-map-marker" />
            <v-text-field v-model="form.as_is_salary" label="Оклад (руб.)" readonly type="number" prepend-icon="mdi-cash" />
            <v-text-field v-model="form.as_is_bonus_month" label="Премия (месяц, %)" readonly type="number" />
            <v-text-field v-model="form.as_is_bonus_quarter" label="Премия (квартал, %)" readonly type="number" />
            <v-text-field v-model="form.as_is_bonus_year" label="Премия (год, %)" readonly type="number" />
          </v-col>
          <v-col cols="12" md="6">
            <h5 class="text-success mb-2">Новое состояние (TO BE)</h5>
            <v-select v-model="form.to_be_position_id" :items="positions" item-title="position_name" item-value="id" label="Новая штатная единица" prepend-icon="mdi-briefcase" @update:modelValue="loadPositionData" />
            <v-text-field v-model="form.to_be_address" label="Адрес" readonly prepend-icon="mdi-map-marker" />
            <v-text-field v-model="form.to_be_salary" label="Оклад (руб.)" readonly type="number" prepend-icon="mdi-cash" />
            <v-text-field v-model="form.to_be_bonus_month" label="Премия (месяц, %)" readonly type="number" />
            <v-text-field v-model="form.to_be_bonus_quarter" label="Премия (квартал, %)" readonly type="number" />
            <v-text-field v-model="form.to_be_bonus_year" label="Премия (год, %)" readonly type="number" />
            <v-text-field v-model="form.transfer_date" label="Дата перевода" type="date" prepend-icon="mdi-calendar" :min="today" />
          </v-col>
        </v-row>
      </div>

      <!-- СЦЕНАРИЙ 2 -->
      <div v-if="scenario === 2">
        <h4 class="mb-3">Ввод новой ставки</h4>
        <v-row>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.date" label="Дата создания" type="date" prepend-icon="mdi-calendar" :min="today" />
            <v-text-field v-model="form.position_name" label="Должность" prepend-icon="mdi-briefcase" />
            <v-text-field v-model="form.address" label="Адрес штатной единицы" prepend-icon="mdi-map-marker" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.salary" label="Оклад (руб.)" type="number" prepend-icon="mdi-cash" />
            <v-text-field v-model="form.bonus_month" label="Премия (месяц, %)" type="number" />
            <v-text-field v-model="form.bonus_quarter" label="Премия (квартал, %)" type="number" />
            <v-text-field v-model="form.bonus_year" label="Премия (год, %)" type="number" />
          </v-col>
        </v-row>
      </div>

      <!-- СЦЕНАРИЙ 3 -->
      <div v-if="scenario === 3">
        <h4 class="mb-3">Вывод существующей ставки</h4>
        <v-select v-model="form.position_id" :items="positions" item-title="position_name" item-value="id" label="Штатная единица" prepend-icon="mdi-briefcase" @update:modelValue="checkPosition" />
        <v-alert v-if="hasEmployee" type="error" variant="tonal" class="mb-3" icon="mdi-alert">⚠ На этой позиции числится сотрудник! Вывод невозможен.</v-alert>
        <v-text-field v-model="form.date" label="Дата вывода штатной единицы" type="date" prepend-icon="mdi-calendar" :min="today" />
      </div>

      <!-- СЦЕНАРИЙ 4 -->
      <div v-if="scenario === 4">
        <h4 class="mb-3">Изменение других условий по штатной единице</h4>
        <v-row>
          <v-col cols="12" md="6">
            <h5 class="text-primary mb-2">Текущее состояние (AS IS)</h5>
            <v-select v-model="form.position_id" :items="positions" item-title="position_name" item-value="id" label="Штатная единица" prepend-icon="mdi-briefcase" @update:modelValue="loadPositionData" />
            <v-text-field v-model="form.date" label="Дата изменения" type="date" prepend-icon="mdi-calendar" :min="today" />
            <v-text-field v-model="form.as_is_address" label="Адрес" readonly prepend-icon="mdi-map-marker" />
            <v-text-field v-model="form.as_is_salary" label="Оклад (руб.)" readonly type="number" prepend-icon="mdi-cash" />
          </v-col>
          <v-col cols="12" md="6">
            <h5 class="text-success mb-2">Новое состояние (TO BE)</h5>
            <v-text-field v-model="form.to_be_position" label="Должность" prepend-icon="mdi-briefcase" />
            <v-text-field v-model="form.to_be_address" label="Адрес" prepend-icon="mdi-map-marker" />
            <v-text-field v-model="form.to_be_salary" label="Оклад (руб.)" type="number" prepend-icon="mdi-cash" />
          </v-col>
        </v-row>
      </div>
    </v-card-text>
    <v-card-actions class="d-flex justify-space-between flex-wrap pa-3">
      <div class="d-flex flex-wrap" style="gap: 8px;">
        <v-btn color="secondary" @click="$router.back()">Отмена</v-btn>
        <v-btn color="primary" @click="save" :loading="loading">
            {{ isEditMode ? 'Сохранить изменения' : 'Сохранить черновик' }}
        </v-btn>
        <v-btn color="success" @click="saveAndSubmit" :loading="loading">
            {{ isEditMode ? 'Сохранить и отправить' : 'Создать и отправить' }}
        </v-btn>
      </div>

      <!-- Кнопка импорта (только для сценария 1) -->
      <v-btn
        v-if="scenario === 1"
        variant="outlined"
        color="secondary"
        prepend-icon="mdi-file-excel"
        @click="triggerImport"
      >
        Импорт из Excel
      </v-btn>
    </v-card-actions>
    <input
      ref="fileInput"
      type="file"
      accept=".xlsx,.xls"
      style="display: none"
      @change="handleImport"
    />
  </v-card>
  <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000" top right>{{ snackbar.text }}</v-snackbar>
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
import { createRequest, submitRequest } from "@/api/requests";
import { getEmployees } from "@/api/employees";
import { getPositions } from "@/api/positions";
import api from "@/api/axios";
import * as XLSX from 'xlsx';

const route = useRoute();
const router = useRouter();
const scenario = ref(null);
const loading = ref(false);
const hasEmployee = ref(false);
const isEditMode = computed(() => !!route.params.id);
const today = new Date().toISOString().split('T')[0];
const snackbar = ref({ show: false, text: '', color: 'success' });
const confirm = ref({ show: false, title: "", text: "", color: "primary", resolve: () => {} });
const fileInput = ref(null);
const triggerImport = () => fileInput.value?.click();

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

const scenarios = [
  { id: 1, name: "Перевод сотрудника на существующую штатную единицу" },
  { id: 2, name: "Ввод новой ставки" },
  { id: 3, name: "Вывод существующей ставки" },
  { id: 4, name: "Изменение условий по штатной единице" },
];

const employees = ref([]);
const positions = ref([]);

const form = ref({
  comment: '',
  description: '',
  employee_id: null,
  position_id: null,
  to_be_position_id: null,
  date: today,
  transfer_date: today,
  position_name: '',
  headcount: 1,
  address: '',
  salary: 0,
  bonus_month: 0,
  bonus_quarter: 0,
  bonus_year: 0,
  as_is_position: '',
  as_is_address: '',
  as_is_salary: 0,
  as_is_bonus_month: 0,
  as_is_bonus_quarter: 0,
  as_is_bonus_year: 0,
  to_be_position: '',
  to_be_address: '',
  to_be_salary: 0,
  to_be_bonus_month: 0,
  to_be_bonus_quarter: 0,
  to_be_bonus_year: 0,
});

const load = async () => {
  employees.value = (await getEmployees()).data;
  positions.value = (await getPositions()).data;
  if (isEditMode.value) await loadRequestData();
};

const loadRequestData = async () => {
  try {
    const res = await api.get(`/requests/${route.params.id}`);
    const request = res.data;
    scenario.value = request.scenario_type;
    
    form.value.comment = request.manager_comment || request.comment || '';
    form.value.description = request.description || '';

    const fieldsRes = await api.get(`/requests/${route.params.id}/fields`);
    const fields = fieldsRes.data;
    
    fields.forEach(field => {
      const name = field.field_name;
      const asIs = field.as_is_value;
      const toBe = field.to_be_value;

      if (name === 'employee_id' && asIs) form.value.employee_id = parseInt(asIs);
      if (name === 'position_id' && asIs) form.value.position_id = parseInt(asIs);
      if (name === 'position_id' && toBe) form.value.to_be_position_id = parseInt(toBe);
      if (name === 'transfer_date' && toBe) form.value.transfer_date = toBe;

      if (scenario.value === 2) {
        if (name === 'date' && toBe) form.value.date = toBe;
        if (name === 'position_name' && toBe) form.value.position_name = toBe;
        if (name === 'headcount' && toBe) form.value.headcount = parseInt(toBe) || 1;
        if (name === 'address' && toBe) form.value.address = toBe || '';
        if (name === 'salary' && toBe) form.value.salary = parseFloat(toBe) || 0;
        if (name === 'bonus_month' && toBe) form.value.bonus_month = parseFloat(toBe) || 0;
        if (name === 'bonus_quarter' && toBe) form.value.bonus_quarter = parseFloat(toBe) || 0;
        if (name === 'bonus_year' && toBe) form.value.bonus_year = parseFloat(toBe) || 0;
      } else {
        if (name === 'salary' && asIs) form.value.as_is_salary = parseFloat(asIs) || 0;
        if (name === 'salary' && toBe) form.value.to_be_salary = parseFloat(toBe) || 0;
        if (name === 'bonus_month' && asIs) form.value.as_is_bonus_month = parseFloat(asIs) || 0;
        if (name === 'bonus_month' && toBe) form.value.to_be_bonus_month = parseFloat(toBe) || 0;
        if (name === 'bonus_quarter' && asIs) form.value.as_is_bonus_quarter = parseFloat(asIs) || 0;
        if (name === 'bonus_quarter' && toBe) form.value.to_be_bonus_quarter = parseFloat(toBe) || 0;
        if (name === 'bonus_year' && asIs) form.value.as_is_bonus_year = parseFloat(asIs) || 0;
        if (name === 'bonus_year' && toBe) form.value.to_be_bonus_year = parseFloat(toBe) || 0;
        if (name === 'date' && toBe) form.value.date = toBe;

        if (name === 'position_name' && asIs) form.value.as_is_position = asIs;
        if (name === 'position_name' && toBe) form.value.to_be_position = toBe;
        if (name === 'headcount' && toBe) form.value.headcount = parseInt(toBe) || 1;
        if (name === 'address' && asIs) form.value.as_is_address = asIs || '';
        if (name === 'address' && toBe) form.value.to_be_address = toBe || '';
      }
    });

    // Запускаем автозаполнение после парсинга ID
    if (form.value.employee_id) await loadEmployeeData(form.value.employee_id);
    if (form.value.to_be_position_id) await loadPositionData(form.value.to_be_position_id);
    if (form.value.position_id) await loadPositionData(form.value.position_id);
    
  } catch (error) {
    console.error('Ошибка загрузки данных заявки:', error);
    showSnackbar('Не удалось загрузить данные заявки', 'error');
    router.back();
  }
};

const onScenarioChange = () => { hasEmployee.value = false; };

const loadEmployeeData = async (employeeId) => {
  if (!employeeId) return;
  const employee = employees.value.find(e => e.id === employeeId);
  if (employee && employee.position_id) {
    const position = positions.value.find(p => p.id === employee.position_id);
    if (position) {
      form.value.as_is_position = position.position_name;
      form.value.as_is_address = position.address || '';
      form.value.as_is_salary = position.salary || 0;
      form.value.as_is_bonus_month = position.bonus_month || 0;
      form.value.as_is_bonus_quarter = position.bonus_quarter || 0;
      form.value.as_is_bonus_year = position.bonus_year || 0;
    }
  }
};

const loadPositionData = async (positionId) => {
  if (!positionId) return;
  const position = positions.value.find(p => p.id === positionId);
  if (position) {
    if (scenario.value === 1) {
      form.value.to_be_position = position.position_name;
      form.value.to_be_address = position.address || '';
      form.value.to_be_salary = position.salary || 0;
      form.value.to_be_bonus_month = position.bonus_month || 0;
      form.value.to_be_bonus_quarter = position.bonus_quarter || 0;
      form.value.to_be_bonus_year = position.bonus_year || 0;
    } else if (scenario.value === 4) {
      form.value.as_is_position = position.position_name;
      form.value.as_is_address = position.address || '';
      form.value.as_is_salary = position.salary || 0;
      
      form.value.to_be_position = position.position_name;
      form.value.to_be_address = position.address || '';
      form.value.to_be_salary = position.salary || 0;
    }
  }
};

const checkPosition = async (positionId) => {
  if (!positionId) return;
  try {
    const res = await api.get(`/positions/${positionId}/check`);
    hasEmployee.value = res.data.has_employee;
  } catch (error) { console.error('Ошибка проверки позиции:', error); }
};

const buildFields = () => {
  const fields = [];
  if (scenario.value === 1) {
    const emp = employees.value.find(e => e.id === form.value.employee_id);
    const currentPosId = emp ? emp.position_id : null;
    fields.push(
      { name: 'employee_id', as_is: String(form.value.employee_id), to_be: null },
      { name: 'position_id', as_is: currentPosId ? String(currentPosId) : null, to_be: String(form.value.to_be_position_id) },
      { name: 'transfer_date', as_is: null, to_be: form.value.transfer_date || null },
      { name: 'salary', as_is: String(form.value.as_is_salary), to_be: String(form.value.to_be_salary) },
      { name: 'bonus_month', as_is: String(form.value.as_is_bonus_month), to_be: String(form.value.to_be_bonus_month) },
      { name: 'bonus_quarter', as_is: String(form.value.as_is_bonus_quarter), to_be: String(form.value.to_be_bonus_quarter) },
      { name: 'bonus_year', as_is: String(form.value.as_is_bonus_year), to_be: String(form.value.to_be_bonus_year) },
    );
  } else if (scenario.value === 2) {
    fields.push(
      { name: 'date', as_is: null, to_be: form.value.date },
      { name: 'position_name', as_is: null, to_be: form.value.position_name },
      { name: 'address', as_is: null, to_be: form.value.address },
      { name: 'salary', as_is: null, to_be: String(form.value.salary) },
      { name: 'bonus_month', as_is: null, to_be: String(form.value.bonus_month) },
      { name: 'bonus_quarter', as_is: null, to_be: String(form.value.bonus_quarter) },
      { name: 'bonus_year', as_is: null, to_be: String(form.value.bonus_year) },
    );
  } else if (scenario.value === 3) {
    fields.push(
      { name: 'position_id', as_is: String(form.value.position_id), to_be: null },
      { name: 'date', as_is: null, to_be: form.value.date },
    );
  } else if (scenario.value === 4) {
    fields.push(
      { name: 'position_id', as_is: String(form.value.position_id || ''), to_be: null },
      { name: 'position_name', as_is: form.value.as_is_position, to_be: form.value.to_be_position },
      { name: 'address', as_is: form.value.as_is_address, to_be: form.value.to_be_address },
      { name: 'salary', as_is: String(form.value.as_is_salary), to_be: String(form.value.to_be_salary) },
    );
  }
  return fields;
};

const save = async () => {
  if (!scenario.value) { showSnackbar('Выберите сценарий!', 'error'); return; }
  if (scenario.value === 3 && hasEmployee.value) {
    showSnackbar('Нельзя вывести штатную единицу, на которой числится сотрудник!', 'error'); return;
  }
  loading.value = true;
  try {
    const payload = {
      scenario_type: scenario.value,
      fields: buildFields(),
      comment: form.value.comment,
      description: form.value.description
    };
    
    if (isEditMode.value) {
      await api.put(`/requests/${route.params.id}`, payload);
      showSnackbar('Заявка успешно обновлена!', 'success');
    } else {
      await createRequest(payload);
      showSnackbar('Заявка успешно создана!', 'success');
    }
    router.push('/requests');
  } catch (error) {
    console.error('Ошибка сохранения заявки:', error);
    const detail = error.response?.data?.detail || error.message;
    showSnackbar('Ошибка при сохранении заявки: ' + detail, 'error');
  } finally { loading.value = false; }
};

const showSnackbar = (text, color = 'success') => {
  snackbar.value = { show: true, text, color };
};

const handleImport = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  
  if (scenario.value !== 1) {
    showSnackbar('Импорт доступен только для сценария "Перевод сотрудника"', 'warning');
    event.target.value = '';
    return;
  }

  if (employees.value.length === 0 || positions.value.length === 0) {
    showSnackbar('Справочники ещё не загружены! Попробуйте через пару секунд', 'warning');
    event.target.value = '';
    return;
  }

  try {
    const buffer = await file.arrayBuffer();
    const wb = XLSX.read(buffer, { cellDates: true });
    let sheetName = wb.SheetNames.find(name => 
      !name.toLowerCase().includes('справочник') && 
      !name.toLowerCase().includes('reference')
    ) || wb.SheetNames[0];

    const ws = wb.Sheets[sheetName];
    console.log('Читаем данные с листа:', sheetName);
    // raw: false гарантирует, что даты и числа придут как строки
    const data = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: false });

    if (data.length < 2) throw new Error('Файл пуст или не содержит заголовков и данных');

    let headerRowIndex = -1;
    const keywords = ['фио сотрудника', 'сотрудник', 'новая ше', 'наименование новой'];
    
    for (let i = 0; i < data.length; i++) {
      const rowStr = data[i].join(' ').toLowerCase();
      // Если в строке найдено хотя бы 2 ключевых слова, считаем это заголовком
      const matches = keywords.filter(k => rowStr.includes(k)).length;
      if (matches >= 2) {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex === -1) {
      throw new Error('Не удалось найти строку с заголовками (ФИО Сотрудника, Новая ШЕ)');
    }

    console.log('Заголовки найдены в строке (индекс):', headerRowIndex);
    
    const headers = data[headerRowIndex].map(h => String(h).trim().toLowerCase());
    const row = data[headerRowIndex + 1].map(v => String(v).trim());

    const getCol = (keywords) => headers.findIndex(h => keywords.some(k => h.includes(k)));
    
    const empCol = getCol(['фио сотрудника', 'сотрудник']);
    const posCol = getCol(['новая ше', 'наименование новой']);
    const dateCol = getCol(['дата перевода', 'дата']);

    if (empCol === -1 || posCol === -1) {
      throw new Error('Не найдены обязательные столбцы: "ФИО сотрудника" и "Новая ШЕ"');
    }

    const empName = row[empCol];
    const posName = row[posCol];

    const emp = employees.value.find(e => e.full_name.toLowerCase() === empName.toLowerCase());
    if (!emp) throw new Error(`Сотрудник "${empName}" не найден в базе`);

    const pos = positions.value.find(p => p.position_name.toLowerCase() === posName.toLowerCase());
    if (!pos) throw new Error(`Штатная единица "${posName}" не найдена в базе`);

    form.value.employee_id = emp.id;
    form.value.to_be_position_id = pos.id;
    if (dateCol !== -1 && row[dateCol]) {
	  const rawDate = row[dateCol];
	  let dateObj = new Date(rawDate);
	  
	  if (isNaN(dateObj.getTime()) && rawDate.includes('.')) {
	    const [d, m, y] = rawDate.split('.');
	    dateObj = new Date(`${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`);
	  }
	  
	  if (!isNaN(dateObj.getTime())) {
	    form.value.transfer_date = dateObj.toISOString().split('T')[0];
	  }
    }
    await loadEmployeeData(emp.id);
    await loadPositionData(pos.id);

    showSnackbar('Данные успешно импортированы!', 'success');
  } catch (err) {
    console.error('Import Error:', err);
    showSnackbar(err.message || 'Ошибка чтения файла', 'error');
  } finally {
    event.target.value = '';
  }
};

const validateRequiredFields = () => {
    if (!scenario.value) { 
        showSnackbar('Выберите сценарий!', 'warning'); 
        return false; 
    }
    const missing = [];

    if (scenario.value === 1) {
        if (!form.value.employee_id) missing.push('Сотрудник');
        if (!form.value.to_be_position_id) missing.push('Новая штатная единица');
        if (!form.value.transfer_date) missing.push('Дата перевода');
    } else if (scenario.value === 2) {
        if (!form.value.position_name?.trim()) missing.push('Должность');
        if (!form.value.address?.trim()) missing.push('Адрес');
    } else if (scenario.value === 3) {
        if (!form.value.position_id) missing.push('Штатная единица');
    } else if (scenario.value === 4) {
        if (!form.value.position_id) missing.push('Штатная единица');
        const toBeHasValue = form.value.to_be_position?.trim() ||
                             form.value.to_be_address?.trim() ||
                             (form.value.to_be_salary && form.value.to_be_salary != 0);
        if (!toBeHasValue) missing.push('Хотя бы одно поле "Новое состояние"');
    }

    if (missing.length > 0) {
        showSnackbar(`Для мгновенной отправки заполните: ${missing.join(', ')}`, 'warning');
        return false;
    }
    return true;
};

const saveAndSubmit = async () => {
    if (!validateRequiredFields()) return;

    if (!scenario.value) { showSnackbar('Выберите сценарий!', 'error'); return; }
    if (scenario.value === 3 && hasEmployee.value) {
        showSnackbar('Нельзя вывести штатную единицу, на которой числится сотрудник!', 'error'); return;
    }
    if (!await showConfirm('Сохранить и отправить?', 'Заявка будет сохранена и сразу отправлена на согласование. Продолжить?', 'success')) return;
    
    loading.value = true;
    try {
        const payload = {
            scenario_type: scenario.value,
            fields: buildFields(),
            comment: form.value.comment,
            description: form.value.description
        };
        
        let requestId = route.params.id;
        if (isEditMode.value) {
            await api.put(`/requests/${requestId}`, payload);
        } else {
            const res = await createRequest(payload);
            requestId = res.data.request_id;
        }
        
        await submitRequest(requestId);
        showSnackbar('Заявка успешно отправлена на согласование!', 'success');
        router.push('/requests');
    } catch (error) {
        console.error('Ошибка сохранения/отправки:', error);
        const detail = error.response?.data?.detail || error.message;
        showSnackbar('Ошибка: ' + detail, 'error');
    } finally { loading.value = false; }
};

onMounted(load);
</script>