import Image from 'next/image'
import { ComponentProps } from 'react'

import logo from '@/public/chriskjaer-logo.svg'

export default function Home() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <div className="flex items-center justify-center px-4">
        <span className="w-3 h-3 mr-0 ns:(mr-4 mt-0)">
          <Image src={logo} alt="chriskjaer logo" />
        </span>

        <div className="pl-4 py-3 ml-4 border-l border-gray-300">
          <h1 className="font-bold font-serif text-f2.5">
            Chris Kjær Sørensen
          </h1>

          <p className="text-f6 ns:text-f5">
            Creative Developer, Software Engineer. CTO & Co-Founder of{' '}
            <A href="https://landfolk.com" rel="Landfolk.com">
              Landfolk
            </A>
          </p>

          <p className="italic text-f6 mt-1">
            Previously: Co-Founder of{' '}
            <A href="https://gaest.com" rel="Gaest.com">
              Gaest.com
            </A>{' '}
            ex-Airbnb.
          </p>
        </div>
      </div>

      <div className="mt-5 ns:mb-5 text-f7 space-x-3">
        <A href="https://www.linkedin.com/in/chriskjaer/">LinkedIn</A>
        <A href="https://github.com/chriskjaer">Github</A>
      </div>
    </div>
  )
}

const A = ({ className, ...props }: ComponentProps<'a'>) => (
  // eslint-disable-next-line jsx-a11y/anchor-has-content
  <a {...props} className={['text-orange underline', className].join(' ')} />
)
