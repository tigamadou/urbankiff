
import { Button } from 'antd';
import Image from 'next/image';
import Link from 'next/link';

import image404 from './../assets/images/404.jpg';
export default function NotFound() {

  return (
    <div className='container'>
      <div className="error-page">
        <Image src={image404} alt="error 404" width={700} layout='responsive' style={{maxWidth: '700px'}} />
        <Link href="/">
          <Button type="primary" color="danger" size="large">Aller à la page d&apos;accueil</Button>

        </Link>


      </div>
    </div>
  );
}
