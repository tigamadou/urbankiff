'use client';
import moment from 'moment';
import React from 'react';
import 'moment/locale/fr';


const Date = ({ time, locale, fromNow, dateTime }) => {
  moment.locale(locale);

  return (
    <time title={moment(time).format('MM/DD/YYYY')}>
      {dateTime ? moment(time).format('LL') + '-' + moment(time).format('HH:mm') : (fromNow ? moment(time).fromNow(true) : moment(time).format('LL'))}

    </time>
  );
};


export { Date };
