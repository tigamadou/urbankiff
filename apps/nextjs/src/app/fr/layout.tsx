import AppFooter from '../components/Footer';
import Navbar from '../components/Navbar/NavBar';


export default function FRLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <main className="app">
      <div className="main-content">
        <Navbar/>
        <div className="page">
          <div className="add-container">
            <div className="add">
              <a href="https://celtiis.bj/" title="Urbankiff" target="_blank">
                <img alt="Urbankiff" src="https://api.urbankiff.com/file/ctjdrne4-uaic-4q3c-9fh5-806aeq70ffp1.webp" />
              </a>
            </div>
          </div>
          {children}
          <AppFooter/>
        </div>
      </div>
    </main>

  );
}
