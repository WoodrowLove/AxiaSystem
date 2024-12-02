import {defineConfig} from '@junobuild/config';

export default defineConfig({
  satellite: {
    id: '2662007',
    source: 'dist',
    predeploy: ['npm run build']
  }
});
