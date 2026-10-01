<script setup lang="ts">
import { reactive, ref, watch } from 'vue';
import { ElMessage, type FormInstance, type FormRules } from 'element-plus';
import { useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';

const props = defineProps<{
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void;
}>();

const router = useRouter();
const auth = useAuthStore();
const formRef = ref<FormInstance>();
const submitting = ref(false);

const form = reactive({
  oldPassword: '',
  newPassword: '',
  confirmPassword: ''
});

const rules: FormRules = {
  oldPassword: [
    { required: true, message: '请输入当前密码', trigger: 'blur' }
  ],
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 6, message: '密码长度不能少于6位', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value && form.oldPassword && value === form.oldPassword) {
          callback(new Error('新密码不能与原密码相同'));
        } else {
          callback();
        }
      },
      trigger: 'blur'
    }
  ],
  confirmPassword: [
    { required: true, message: '请确认新密码', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value !== form.newPassword) {
          callback(new Error('两次输入的新密码不一致'));
        } else {
          callback();
        }
      },
      trigger: 'blur'
    }
  ]
};

function handleClose() {
  emit('update:visible', false);
  form.oldPassword = '';
  form.newPassword = '';
  form.confirmPassword = '';
  formRef.value?.resetFields();
}

async function submit() {
  if (!formRef.value) return;
  await formRef.value.validate();
  submitting.value = true;
  try {
    await request.put('/api/auth/password', {
      oldPassword: form.oldPassword,
      newPassword: form.newPassword
    });
    ElMessage.success('密码修改成功，请使用新密码重新登录');
    handleClose();
    auth.logoutLocal();
    await router.replace('/login');
  } finally {
    submitting.value = false;
  }
}

watch(
  () => props.visible,
  (val) => {
    if (!val) {
      form.oldPassword = '';
      form.newPassword = '';
      form.confirmPassword = '';
    }
  }
);
</script>

<template>
  <el-dialog
    :model-value="props.visible"
    title="修改个人密码"
    width="440px"
    destroy-on-close
    :close-on-click-modal="false"
    @close="handleClose"
  >
    <el-alert
      title="修改密码成功后将退出当前登录状态，需使用新密码重新登录。"
      type="info"
      :closable="false"
      show-icon
      style="margin-bottom: 20px"
    />
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-width="95px"
      status-icon
      @submit.prevent="submit"
    >
      <el-form-item label="原密码" prop="oldPassword">
        <el-input
          v-model="form.oldPassword"
          type="password"
          show-password
          placeholder="请输入当前原密码"
        />
      </el-form-item>
      <el-form-item label="新密码" prop="newPassword">
        <el-input
          v-model="form.newPassword"
          type="password"
          show-password
          placeholder="不少于6位，且与原密码不同"
        />
      </el-form-item>
      <el-form-item label="确认新密码" prop="confirmPassword">
        <el-input
          v-model="form.confirmPassword"
          type="password"
          show-password
          placeholder="请再次输入新密码"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button type="primary" :loading="submitting" @click="submit">确认修改</el-button>
    </template>
  </el-dialog>
</template>
