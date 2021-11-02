import {
  defineDocumentType,
  makeSource,
  ComputedFields,
} from 'contentlayer/source-files'

const computedFields: ComputedFields = {
  slug: {
    type: 'string',
    resolve: (doc) => doc._raw.sourceFileName.replace(/\.mdx?$/, ''),
  },
}

export const Note = defineDocumentType(() => ({
  name: 'Note',
  filePathPattern: `notes/*.md`,
  fields: {
    title: { type: 'string', required: true },
  },
  computedFields,
}))

export default makeSource({
  contentDirPath: 'data',
  documentTypes: [Note],
  markdown: { rehypePlugins: [] },
})
