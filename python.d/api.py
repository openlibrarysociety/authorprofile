#!/usr/bin/python

from authorprofile.network import getMongoDBAunexes
import web

urls = (
  '/api/aunex/(.*)', 'aunex',
#  '/api/author/(.*)', 'author'
)

app = web.application(urls, globals())

class aunex:
    def GET(self,namestring):
        # 'aunex' -> NAMESTRING -> time of serialization
        # treat an object as a set of data structures representing properties
        # and property values
        return getMongoDBAunexes(namestring,host='holda')

if __name__ == "__main__": app.run()

#conn=getMongoDBConn('holda')
#print normalizeAunex('Daniel Richards')
#aun=getMongoDBAunexes('Daniel Richards',host='holda').pop(0)

#print aun.__dict__

#conn.disconnect()
