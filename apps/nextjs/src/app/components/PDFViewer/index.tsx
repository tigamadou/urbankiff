/* eslint-disable @typescript-eslint/no-unused-vars */
'use client'; // Required for Next.js App Router

import { EditFilled } from '@ant-design/icons';
import { Tag, Flex } from 'antd';
import moment from 'moment';
import { useState, useEffect } from 'react';
import { Document, Page, pdfjs, DocumentProps } from 'react-pdf';

import './style.sass';

pdfjs.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjs.version}/pdf.worker.min.mjs`;

// Move locale detection to useEffect to avoid build-time issues
let userLocale = 'en'; // Default fallback

interface PDFViewerProps {
  fileUrl: string;
}

const PDFViewer: React.FC<PDFViewerProps> = ({fileUrl}) => {
  const [numPages, setNumPages] = useState<number | null>(null);
  const [lastModified, setLastModified] = useState<string | null>(null);

  const [pageNumber, setPageNumber] = useState<number>(1);
  const onDocumentLoadSuccess: DocumentProps['onLoadSuccess'] = ({ numPages }) => {
    setNumPages(numPages);
  };

  useEffect(() => {
    // Set locale after component mounts (client-side only)
    if (typeof window !== 'undefined') {
      userLocale = navigator.language || navigator.languages[0] || 'en';
      moment.locale(userLocale);
    }

    const fetchMetadata = async () => {
      try {
        const pdf = await pdfjs.getDocument(fileUrl).promise;
        const metadata = await pdf.getMetadata();
        const { ModDate } = metadata.info as { ModDate: string };

        if (ModDate) {
          // Convert PDF date format to human-readable format
          const modifiedDate = ModDate.replace('D:', '').replaceAll("'", '');
          const formattedDate = moment(modifiedDate, 'YYYYMMDDHHmmss').format('DD/MM/YYYY HH:mm');
          setLastModified(formattedDate);
        }
      } catch (error) {
        console.error('Error loading PDF metadata:', error);
      }
    };

    fetchMetadata();
  }, [fileUrl]);

  return (
    <div className="pdf-viewer">
      <Document className="pdf-viewer-document" file={fileUrl} onLoadSuccess={onDocumentLoadSuccess} >
        {Array.from(new Array(numPages || 0), (_, index) => (
          <Page
            className="pdf-viewer-page"
            renderTextLayer={false}
            renderAnnotationLayer={false}
            key={`page_${index + 1}`}
            pageNumber={index + 1}
            scale={4}
            width={700}
            height={700 * (11.69 / 8.27)}
          />
        ))}

      </Document>
      <Flex justify="center">

        {lastModified &&
                <>
                  <Tag> <EditFilled/> {lastModified}</Tag>
                </>
        }
      </Flex>

    </div>
  );
};

export default PDFViewer;
