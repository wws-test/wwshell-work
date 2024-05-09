<template>
    <AppPage :show-footer="false">
      <div>
        <n-input v-model="jsonData" placeholder="请输入JSON格式的数据" @change="formatJson" />
        <vue-json-pretty :data="parsedJsonData" />
      </div>
    </AppPage>
  </template>
  
  <script>
  import VueJsonPretty from 'vue-json-pretty'
  import 'vue-json-pretty/lib/styles.css'
  import AppPage from '@/components/page/AppPage.vue'
  import { NInput } from 'naive-ui'
  
  export default {
    components: {
      AppPage,
      VueJsonPretty,
      NInput,
    },
    data() {
      return {
        jsonData: '',
        parsedJsonData: null,
      }
    },
    methods: {
      formatJson() {
        try {
          const trimmedData = this.jsonData.trim()
          this.parsedJsonData = JSON.parse(trimmedData)
        } catch (error) {
          this.parsedJsonData = { error: 'Invalid JSON format' }
        }
      },
    },
  }
  </script>
  