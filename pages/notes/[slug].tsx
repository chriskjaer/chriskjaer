import 'twin.macro'
import { allNotes } from '.contentlayer/data'
import type { Note } from '.contentlayer/types'
import { GetStaticPropsContext } from 'next'

export default function NotePage({ note }: { note: Note }) {
  return (
    <>
      <h1 tw='text-f2'>{note.title}</h1>
      <div tw="prose" dangerouslySetInnerHTML={{ __html: note.body.html }} />
    </>
  )
}

export async function getStaticPaths() {
  return {
    paths: allNotes.map((p) => ({ params: { slug: p.slug } })),
    fallback: false,
  }
}

export async function getStaticProps({ params }: GetStaticPropsContext) {
  const note = allNotes.find((note) => note.slug === params?.slug)

  return { props: { note } }
}
