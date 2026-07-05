type IpcListener = (...args: any[]) => void

const ipcChannels: Record<string, Set<IpcListener>> = {}

export const clipboard = {
  writeText: (text: string) => {
    navigator.clipboard.writeText(text)
  },
  readText: () => '',
}

export const webUtils = {
  getPathForFile: (file: any) => file.path,
}

export const ipcRenderer = {
  invoke: async (_channel: string, ..._args: any[]) => {},
  send: (_channel: string, ..._args: any[]) => {},
  sendSync: (_channel: string, ..._args: any[]) => {},
  on: (channel: string, listener: IpcListener) => {
    if (!ipcChannels[channel]) ipcChannels[channel] = new Set()
    ipcChannels[channel].add(listener)
  },
  once: (channel: string, listener: IpcListener) => {
    const onceWrapper = (...args: any[]) => {
      listener(...args)
      ipcRenderer.removeListener(channel, onceWrapper)
    }
    ipcRenderer.on(channel, onceWrapper)
  },
  removeListener: (channel: string, listener: IpcListener) => {
    ipcChannels[channel]?.delete(listener)
  },
  removeAllListeners: (channel: string) => {
    delete ipcChannels[channel]
  },
}

export const shell = {
  openExternal: (url: string) => window.open(url, '_blank'),
  openPath: async (_path: string) => '',
  showItemInFolder: (_path: string) => {},
  moveItemToTrash: async (_path: string) => true,
  beep: () => {},
}

export const remote = {
  app: {
    getPath: (_name: string) => '',
    getAppPath: () => '',
  },
  getCurrentWindow: () => ({
    setTitle: (_t: string) => {},
    isFocused: () => true,
    on: (_e: string, _cb: Function) => {},
    removeListener: (_e: string, _cb: Function) => {},
    close: () => {},
    minimize: () => {},
    maximize: () => {},
    unmaximize: () => {},
    isMaximized: () => false,
    isMinimized: () => false,
    focus: () => {},
    show: () => {},
    hide: () => {},
    setSkipTaskbar: (_b: boolean) => {},
    setMenuBarVisibility: (_b: boolean) => {},
  }),
  getCurrentWebContents: () => ({
    session: {
      webRequest: undefined,
      resolveProxy: async (_url: string) => 'DIRECT',
    },
    setZoomFactor: (_f: number) => {},
    getZoomFactor: () => 1,
  }),
  dialog: {
    showOpenDialog: async () => ({ canceled: false, filePaths: [] }),
    showSaveDialog: async () => ({ canceled: false, filePath: '' }),
    showMessageBox: async () => ({ response: 0 }),
  },
  Menu: {
    buildFromTemplate: () => ({ popup: () => {} }),
    setApplicationMenu: () => {},
  },
  MenuItem: class {},
  nativeImage: {
    createFromPath: () => ({ toDataURL: () => '', resize: () => ({}) }),
    createEmpty: () => ({ toDataURL: () => '' }),
  },
}

export const app = {
  getVersion: () => '0.0.0',
  getName: () => 'GitHub Desktop',
  getPath: (_name: string) => '',
  getAppPath: () => '',
  on: (_e: string, _cb: Function) => {},
  quit: () => {},
}

export const dialog = {
  showOpenDialog: async () => ({ canceled: false, filePaths: [] }),
  showSaveDialog: async () => ({ canceled: false, filePath: '' }),
  showMessageBox: async () => ({ response: 0 }),
}

export const nativeTheme = {
  shouldUseDarkColors: false,
  themeSource: 'system',
  on: (_e: string, _cb: Function) => {},
}

export type IpcRendererEvent = { sender: any }
