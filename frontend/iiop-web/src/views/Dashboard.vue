<script setup lang="ts">
import { onMounted, ref } from 'vue'; import { request } from '../api/request';
const data=ref<any>(),loading=ref(true); onMounted(async()=>{try{data.value=await request.get('/api/device/statistics/overview')}finally{loading.value=false}});
</script><template><h1>运行总览</h1><el-skeleton :loading="loading" animated><el-card><h2>{{data?.deviceTotal??0}} 台设备</h2><pre>{{data?.byStatus}}</pre></el-card></el-skeleton></template>
