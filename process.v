`timescale 1ns / 1ps

//ai cum sa ma ajuti cu un proiect in verilog? daca esti de acord, da mi add pe discord @bodlex

module process (
        input                clk,		    	// clock 
        input  [23:0]        in_pix,	        // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
        input  [8*512-1:0]   hiding_string,     // sirul care trebuie codat
        output reg [6-1:0]       row, col, 	        // selecteaza un rand si o coloana din imagine
        output reg              out_we, 		    // activeaza scrierea pentru imaginea de iesire (write enable)
        output reg [23:0]        out_pix,	        // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
        output reg              gray_done,		    // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
        output reg             compress_done,		// semnaleaza terminarea actiunii de compresie (activ pe 1)
        output reg              encode_done        // semnaleaza terminarea actiunii de codare (activ pe 1)
    );	
	 
	 //Variabile necesare conectarii celor doua module
	 
	  parameter width      = 16;
     parameter base       = 3;
     parameter base_width = 2;
	  wire [base_width*width - 1 : 0] base3_no;
	  reg [width - 1 : 0]base2_no;
	  wire done;
	  reg en;
	  
	  //Se instantiaza modulul base2tobase3
	 base2_to_base3 #(width,base,base_width) b2tb3 (.base3_no(base3_no), .done(done), .base2_no(base2_no), .en(en), .clk(clk));
    
	 //Starile automatului - explicat pe larg in README
	 
	 `define CITIRE 0
	 `define CALCULARE 1
	 `define STOCARE 2
	 `define FINALIZARE 3
	 `define INITIERE 4
	 `define CITIRE_COMP 5
	 `define AVG 6
	 `define CITIRE_COMP1 7
	 `define VAR 8
	 `define BITMAP 9
	 `define CITIRE_COMP2 10
	 `define CALCULARE_COMP 11
	 `define CITIRE_COMP3 12
	 `define CONSTRUCTIE 13
	 `define FINALIZARE_COMP 14
	 `define INITIERE1 15
	 `define SETARE_CONV 16
	 `define CONVERSIE 17
	 `define CITIRE_CODARE 18
	 `define IDENTIFICARE_FL_FH 19
	 `define CITIRE_CODARE1 20
	 `define SALVARE1 21
	 `define INCREMENTARE 22
	 `define FINALIZARE_CODARE 23
	 
	 
	 
	 //iteratori pentru parcurgerea row si col, si a tablourilor/memoriilor
	 reg [7 : 0] i = 0, j = 0, k = 0, l = 0;
	 reg [12 : 0] d = 0;
	 reg [7 : 0] m = 0, n = 0;
	 reg [3 : 0] h = 0;
	 reg [7 : 0] z = 0, x = 0, c = 0;
	 reg [7 : 0] v = 0, b = 0;
	 
	 // memorie pentru a retine fiecare valoare a mediei pentru blocurile individuale
	 reg [23 : 0] avg_mat[3 : 0][3 : 0];
	 
	 // variabile de tip integer pentru a incrementa sau actualiza dupa necesitati
	 //suma, valoarea absoluta, indicele beta,etc.
	 
	 integer sum = 0, sum_var = 0, abs = 0, beta = 0, counter = 0;
	 
	 //variabile de tip register unde salvez valoarea mediei si valoarea lui var
	 reg [7 : 0] avg = 0, var = 0;
	 reg [7 : 0] max = 0, min = 0;
	 
	 //G- declarat pe opt biti, pentru a calcula media celor doua valori (la partea de)
	 //grayscale
	 reg [7 : 0] G = 0;
	 reg [5 : 0] state = 0, state_next = 0; 
	 
	 //Memorie in care pastrez valorile de 1 si 0 din blocul de compresie pentru a putea 
	 //rescrie mai apoi blocul in varianta finala in functie de L si H
	 reg [23 : 0] array[3 : 0][3 : 0];
	 reg [7 : 0] L = 0, H = 0;
	 
	 //utilizat pentru partea codare, daca am gasit high low si first low devine 1 si 
	 //putem trece intr-o alta stare 
	 reg gasit;

	//variabilele coutner utilizate pentru a stoca pozitiile Lm si Hm de la partea de codare
	 reg [7 : 0] countl1 = 0, countl2 = 0;
	 reg [7 : 0] counth1 = 0, counth2 = 0;
	
	//un counter prin care verific daca intreg blocul de 16 elemente a fost parcurs, iar daca
	//a fost parcurs in intregime/ counter_LH = 15 inseamna ca Lm si Hm au aceeasi valoare.
	
	 reg [7 : 0] counter_LH = 0;
	 reg [7 : 0] Lm = 0, Hm = 0;
	 
	 //Un registru pe 2 biti cu 16 elemente pentru a stoca valoarea lui base3_no 
	 reg [1 : 0] biti [15 : 0];
	 
	 	 always@(posedge clk) begin
				state <= state_next;
		 end
	 
	 always@(*) begin
	 
	 //setam semnalele care sunt initial active in semnale inactive
		out_we = 0;
		gray_done = 0;
		compress_done = 0;
		encode_done = 0;
		en = 0;
		gasit = 0;
		case(state)
		
		//Conversia RGB to Grayscale
		
		//CITIRE: starea initiala, in care setam pentru row si col valorile 
		//			iteratorilor i si j astfel incat sa putem obtine valorile 
		//			dorite pentru R, G, B  de la inputul in_pix
			`CITIRE: begin
				row = i;
				col = j;
				state_next = `CALCULARE;
			end
		
		//CALCULARE : Dupa ce citim valorile lui row si col, mergem in starea
		//				 de calculare unde verificam maximul si minimul celor 3 canale
		//				 urmand ca G sa primeasca valoarea mediei maximului si minimului
		//				 identificat din cele 3 canale
			`CALCULARE: begin
				if(in_pix[23 : 16] >= in_pix[15 : 8] &&  in_pix[23 : 16] >= in_pix[7 : 0]) begin
							max = in_pix[23 : 16];
						end 
						else 
							if(in_pix[15 : 8] >=in_pix[23 : 16] && in_pix[15 : 8] >= in_pix[7 : 0]) begin
								max = in_pix[15 : 8];
							end
							else begin
								max = in_pix[7 : 0];
							end
						if(in_pix[23 : 16]<= in_pix[15 : 8] && in_pix[23 : 16]<= in_pix[7 : 0]) begin
							min = in_pix[23 : 16];
						end
						else
							if(in_pix[15 : 8] <=in_pix[23 : 16] && in_pix[15 : 8] <= in_pix[7 : 0])begin
								min = in_pix[15 : 8];
							end
							else begin
								min = in_pix[7 : 0];
							end
				  G = (max + min)/2;
				  
				  state_next = `STOCARE;
			end
			
			//STOCARE: 	Starea in care valorile output-urilor sunt rescrise, drept urmare 
			//			 setam semnalul write enable ca fiind activ, dupa care valorile
			//			 R si B [23:16] si [7 : 0] primesc valoarea 0, iar G - ul primeste
			//			 valoarea registrului G calculat in starea anterioara
			
				`STOCARE: begin
					out_we = 1;
					out_pix[23 : 16] = 0;
					out_pix[15 : 8] = G;
					out_pix[7  : 0] = 0;
					
			//	O conditie de parcurgere/incrementare ce va fi utilizata si la celelalte 
			//task-uri dar sub o alta forma
			//Parcurgem liniile pana la a 64 a linie, iar in momentul in care am 
			//ajuns la a 64 a linie ne mutam pe urmatoarea coloana. 
			//In momentul in care ajungem si la a 64 a coloana conversia a luat
			//sfarsit, drept urmare mergem in starea de finalizare unde setam
			//semnalul gray done ca fiind activ
					if(j==63 && i==63) state_next = `FINALIZARE;
					else begin i = i + 1;
								if(i == 64) begin
									j = j + 1; 
									i = 0;
							end
					state_next= `CITIRE;
					end
						
				end
					
					//Dupa finalizarea conversiei in grayscale intram in urmatoarea
					//stare, cea de INITIERE a compresiei
					
					`FINALIZARE: begin
						gray_done = 1;
						state_next = `INITIERE;
					end
					
					//Compresia prin AMBTC
					
					//INITIERE : Dupa parcurgerile anterioare, este necesara o
					//				reinitializare a valorilor iteratorilor, dar si
					//				a registrilor row si col
					
					`INITIERE: begin
		
						i = 0;
						j = 0;
						k = 0;
						l = 0;
						row = 0;
						col = 0;
						state_next= `CITIRE_COMP;
					end
					
					//CITIRE_COMP : O stare asemanatoare celei de la RGB to grayscale
					//					prin care setam valorile lui row si col
					`CITIRE_COMP: begin
						
						row = i;
						col = j;			
						state_next = `AVG;
						
					end
					
					//AVG : Average, starea unde calculez media aritmetica sub urmatoarea
					//		 forma : in memoria avg_mat "memorez" valorile G - urilor calculate
					//		 la task-ul anterior. Aceasta memorie va fi utilizata si la calculul
					// 	deviatiei standard.
					//			In continuare in valoarea integer-ului suma, calculam suma totala a 
					//		valorilor din blocul in care lucram. Dupa calcularea sumei(aceasta este)
					// 	determinata ca fiind finalizata atunci cand iteratorii i si j ating valoarea
					// 	maxima a indicilor blocului respectiv; ex : (i,j) = (3,3)), calculam media
					//		ca fiind suma calculata / 16 si mergem in urmatoarea stare.
					`AVG: begin
						
						avg_mat[k][l] = in_pix[15:8];			
						sum = sum + avg_mat[k][l];
						
						
						//	Ideea acestei parcurgei este urmatoarea :
						//	m si n sunt valori de incrementare prin care impart intreaga imagine
						//in blocuri de 4x4.
						//	Mai exact, pe exemplul initial, m = 0 si n = 0
						//	Adica transpus in cod, Daca i si j ating valoarea 0 + 4 - 1 = 3
						// Asta inseamna ca am parcurs blocul si media a fost calculata pe 
						//blocul respectiv. i ia acum valoarea lui m, si j valoarea lui n
						//iar k si l sunt intializati cu 0
						//	Daca NU						
						//	Parcurgem apoi in aceeasi maniera precum la taskul anterior blocul
						//pe linii si incrementam/modificam liniile si valorile indicilor 
						//pentru memoria avg_mat[k][l]
						//La finalul constructiei blocului(adica atunci cand schimbam pentru
						//pozitiile de 0 si 1 din bloc cu Lm si Hm, consideram constructia 
						//blocului finalizata si incrementam valorile fie m fie n cu 4)
						// Mai exact, parcurgem blocurile de 4x4 pe linii iar cand ajungem la 
						//ultimul bloc de 4x4 ne mutam pe prima linie de blocuri, dar pe urmatoarea
						//coloana 
						
							if(i == m + 4 - 1 && j == n + 4 - 1) begin
								avg = sum/16;
								i = m;
								j = n;
								k = 0;
								l = 0;
								state_next = `CITIRE_COMP1;
							end
								else begin
									i = i + 1;
									k = k + 1;
									if(i == m + 4) begin
										j = j + 1;
										l = l + 1;
										i = m;
										k = 0;
									end
								state_next = `CITIRE_COMP;	
								end
								
					end
					
					//CITIRE_COMP1 : Dorim sa obtinem din nou valorile randurilor si coloanelor
					//					
					`CITIRE_COMP1: begin
						row = i;
						col = j;
						state_next = `VAR;					
					end
					
					//VAR: Deviatia standard
					//		 Utilizam memoria avg_mat pentru a stoca valorile pixelilor, pe care
					// 	 urmam sa o folosim in calcularea modulului(valorii absolute)
					//		 abs este valoarea pixelului minus valoarea lui AVG. Daca aceasta
					//		este pozitiva la suma noastra se va aduna valoarea lui abs, iar daca
					// 	aceasta este negativa, inmultim cu -1 ca acesta sa fie transformata in
					// 	una pozitiva.
					//		Dupa parcurgerea blocului, deviatia standard ia valoarea sumei finale
					//		calculate, impartita la 16, apoi trecem in urmatoarea etapa/stare.
					
					`VAR: begin
						avg_mat[k][l] = in_pix[15:8];
						abs = avg_mat[k][l] - avg;
						if(abs > 0)begin
							sum_var = sum_var + abs;
						end
						else begin
							sum_var = sum_var + (-1)*abs;
						end
						if(i == m + 4 - 1 && j == n + 4 - 1) begin
							var = sum_var/16;
							i = m;
							j = n;
							k = 0;
							l = 0;
							state_next = `CITIRE_COMP2;
						end
							else begin
								i = i + 1;
								k = k + 1;
								if(i == m + 4) begin
										j = j + 1;
										l = l + 1;
										i = m;
										k = 0;
								end
							state_next = `CITIRE_COMP1;	
							end							
					end
					
					`CITIRE_COMP2: begin
						row = i;
						col = j;
						state_next = `BITMAP;					
					end
					
					//BITMAP :  Este starea in care construim o harta, si ne folosim de cealalta
					//			memorie array.
					//				Daca valoarea stocata valoarea pixelului stocata in memorica avg_mat
					//			este mai mica decat avg, stocam pe pozitia respectiva valoarea 0 in
					//			memoria array, altfel stocam valoarea 1 si incrementam valoarea indicelui
					//			beta cu 1.
					//				Apoi parcurg blocul in aceeasi maniera si trec in starea de calculare
					// 		a valorilor Lm si Hm
					
					`BITMAP: begin
						avg_mat[k][l] = in_pix[15:8];						
						if(avg_mat[k][l] < avg)begin
							array[k][l] = 0;
						end
						else begin
							array[k][l] = 1;
							beta = beta + 1;
						end
						if(i == m + 4 - 1 && j == n + 4 - 1) begin
							k = 0;
							l = 0;
							state_next = `CALCULARE_COMP;
						end
							else begin
								i = i + 1;
								k = k + 1;
								if(i == m + 4) begin
									j = j + 1;
									l = l + 1;
									i = m;
									k = 0;
								end
							state_next = `CITIRE_COMP2;	
							end	
						
					end
					
					//CALCULARE_COMP : Starea in care calculam valorile Lm si Hm in functie de
					//						formulele oferite
					
					`CALCULARE_COMP: begin
						L = avg - (16 * var) / (2 * (16 - beta));
						H = avg + (16 * var) / (2 * beta);
						i = m;
						j = n;
						k = 0;
						l = 0;
						state_next = `CITIRE_COMP3;
						
					end
					`CITIRE_COMP3: begin
						row = i;
						col = j;
						state_next = `CONSTRUCTIE;					
					end
					
					//CONSTRUCTIE : Starea in care stocam valorile lui L si H in blocul de 4x4
					//					in functie de pozitiile marcate cu 0 si 1.
					//					 Totodata aceasta este si starea in care incrementam valoarea
					//					indicilor ce ne definesc blocul pe care lucram (mai simplu ne
					//					mutam pe un alt bloc, intai pe linia de blocuri, apoi parcurgem
					//					o alta coloana)
					
					`CONSTRUCTIE: begin
						out_we = 1;
						if(array[k][l] == 0)begin
							out_pix[15 : 8] = L;
						end
						else begin
							out_pix[15 : 8] = H;
						end
						if(i == m + 4 - 1 && j == n + 4 - 1) begin
							if(m == 60 && n == 60)begin
								state_next = `FINALIZARE_COMP;
							end
							else begin
								m = m  + 4;
								if(m == 64) begin
									n = n + 4;
									m = 0;
								end
								i = m;
								j = n;
								k = 0;
								l = 0;
								sum = 0;
								sum_var = 0;
								beta = 0;
								avg = 0;
								state_next = `CITIRE_COMP;
							end
						end
							else begin
								i = i + 1;
								k = k + 1;
								if(i == m + 4) begin
									j = j + 1;
									l = l + 1;
									i = m;
									k = 0;
								end
							state_next = `CITIRE_COMP3;	
							end	
					end
					
					//	FINALIZARE_COMP : Dupa ce am parcurs intreaga imagine pe blocuri/ am finalizat 
					//parcurgerea ultimului bloc 60-60, compresia a luat sfarist, prin urmare setam
					//semnalul compress_done ca fiind activ.
					`FINALIZARE_COMP: begin
					
						i = 0;
						j = 0;
						k = 0;
						l = 0;
						row = 0;
						col = 0;
						m = 0;
						n = 0;
						compress_done = 1;
						state_next = `INITIERE1;
					end	
					
					//Incapsularea mesajului 
					
					//INITIERE1 : Starea in care initializam valorile coloanelor si randurilor

				   `INITIERE1: begin
				
						row = i;
						col = j;
						gasit = 0;	
						state_next= `SETARE_CONV;
					end
							
					//SETARE_CONV :  Setare conversie, setam practic valoarea lui base2_no, numarul
					//					ce urmeaza sa fie convertit in baza 3.
					//					  Ideea este urmatoarea : 
					//					  Setam ca fiind activ semnalul enable si setam primii 8 biti valoarea
					//					caracterului ascii din string codat pe 8 biti sub forma recomandata
					//					in cadrul cerintei temei si a standardului verilog 2000, 
					//					din hiding string ultimul caracter, apoi incrementez d - ul cu 8
					// 				pentru a avansa la penultimul caracter, si tot asa din 2 in 2 pentru
					//					intreaga dimensiune a imaginii. Automat cand string-ul se va termina 
					//					Valorile rezultate in urma conversiei vor fi 0, drept urmare valorile 
					//					pixelilor nu vor fi afectate.
					
					`SETARE_CONV: begin
					
							en = 1;							
							base2_no[7 : 0] = hiding_string[d+:16];
							d = d + 8;
							base2_no[15 : 8] = hiding_string[d+:16];
							d = d + 8;
							state_next = `CONVERSIE;
					end
					
					//CONVERSIE : O stare de asteptare in care poposim pana semnalul
					//				done devine activ, prin urmare conversia in baza 3 a 
					//				luat sfarsit.
					//				  Totodata, pentru a usura procesul de salvare a
					//				valorilor codate in final, utilizez un registru de 2
					//				biti, pe 16 cuvinte, asemanator celui utilizat la Tema1
					//				pentru a stoca valorile rezultate in urma convertirii
					//				sub forma propusa in cadrul cerintei (si mai usor de 
					//				verificat daca aceasta conversie a fost realizata corect
					//				in faza de debugging)
					
					
					`CONVERSIE: begin
						if(done == 1)begin
							for(v = 0; v <= 13; v = v + 1)begin
								biti[v][0] = base3_no[2*v];
								biti[v][1] = base3_no[2*v + 1];
							end
							if(base3_no == 0)begin
								state_next = `FINALIZARE_CODARE;
								
							end
							state_next = `CITIRE_CODARE;
						end
						else begin
							state_next = `CONVERSIE;
						end
					end
					
					
					`CITIRE_CODARE: begin
						row = i; 
						col = j;
						if(gasit == 1)begin 
							state_next = `SALVARE1;
						end
						else begin
							state_next = `IDENTIFICARE_FL_FH;
						end
					end
					
					//IDENTIFICARE_FL_FH :	Starea in care imi identific First Low Lm
					//							si First High Hm. 
					//								Pe unul dintre ei(am considerat Lm) il gasesc
					//							pe prima pozitie in orice bloc, drept urmare ii setez 
					//							indicii ca fiind i si j/ indicii initiali ai blocului
					//							si stochez valoarea ca fiind prima valoare din blocul
					//							in care lucrez.
					//								Prima valoare diferita de Lm ii este atribuita registrului
					//							Hm caruia ii salvam de asemenea pozitiile, setam variabila gasit 					
					//							cu 1, pentru a marca faptul ca am identificat atat Lm-ul cat si Hm-ul
					//							si putem merge catre starea de salvare a valorilor codate. In situatia in care
					//							Lm si Hm au aceleasi valoare, indicii pozitiei lor vor fi identici in aceasta stare
					//							si setam gasit pe 1 pentru a putea trece in starea urmatoare. In cazul
					//							in care valorile nu au fost identificate parcurgem blocul pana identificam
					//							valorile respective, sau, in cazul in care valorile sunt identice pe tot parcursul
					//							blocului avem un counter care in momentul atingerii valorii 16 ne confirma faptul
					//							ca valorile lui Hm si Lm sunt identice
					`IDENTIFICARE_FL_FH: begin
						counter_LH = counter_LH + 1;
						if(i == m && j == n)begin
							//poz pe care e L
							countl1 = i;
							countl2 = j;
							out_we = 1;
							Lm = in_pix[15 : 8];
							out_pix[15 : 8] = Lm;
							out_we = 0;
						end 
						else begin
							if(in_pix[15 : 8] != Lm)begin
								counth1 = i;
								counth2 = j;
								Hm = in_pix[15 : 8];
								gasit = 1;
								end
								else begin
									if(counter_LH == 16)begin
										counter_LH = 0;
										counth1 = countl1;
										counth2 = countl2;
										Hm = Lm;
										gasit = 1;
									end
								end
						end
						if(gasit == 1)begin
							counter_LH = 0;
							i = m;
							j = n;
							state_next = `CITIRE_CODARE1;
						end
						else begin
							if(i == m + 4 - 1 && j == n + 4 - 1) begin
								i = m;
								j = n;
								state_next = `CITIRE_CODARE1;
							end
							else begin
								j = j + 1;
								if(j == n + 4) begin
									i = i + 1;
									j = n;
								end
								state_next = `CITIRE_CODARE;
							end
						end
					end
					
						`CITIRE_CODARE1: begin
						row = i; 
						col = j;
						state_next = `SALVARE1;
					end
					
					//SALVARE1 : Starea in care stocam in bloc valorile codificate
					//				 Algoritmul implementat este asemanator celui din
					//			  anexa temei, cu mici personalizari astfel :
					//				Cum, doresc sa stochez in bloc valori, setez semnalul
					//			write_enable ca fiind activ. Apoi verific integritatea 
					//			valorilor Lm si Hm. Daca ele sunt identice, in prima faza
					//			pixelul de pe prima pozitie primeste aceeasi valoare cu cea
					//			a lui Lm si incrementez valoarea coloanei lui Hm pentru a il
					// 		seta ca fiind al doilea termen de pe rand ce nu trebuie modificat
					//				Altfel, daca nu sunt identice, daca ne aflam pe pozitia indicilor
					//			Lm si Hm, nu efectuam nicio operatie asupra valorii ce urmeaza sa fie
					//			salvata din bloc.
					//				Altfel, daca valoarea respectiva nu e nici Lm si nici Hm, in functie
					//			de valoarea bitului respectiv se modifica valoarea stocata, si incrementam
					// 		valoarea lui h- iteratorul de parcurgere al numarului convertit in baza 3.
					`SALVARE1: begin
						out_we = 1;
						if(counth1 == countl1 && countl2 == counth2)begin
							counth1 = countl1;
							counth2 = countl2 + 1;
						end
						else begin
							if(row == countl1 && col == countl2)begin
								out_pix[15 : 8] = in_pix[15 : 8];
							end
							else begin
								if(row == counth1 && col == counth2)begin
									out_pix[15 : 8] = in_pix[15 : 8];
								end
								else begin
									if(biti[h] == 0)begin
										out_pix[15 : 8] =  in_pix[15 : 8];										
										h = h + 1;
									end
									else begin
										if(biti[h] == 1)begin
											out_pix[15 : 8] = in_pix[15 : 8] + 1;
											h = h + 1;
										
										end
										else begin
											if(biti[h] == 2)begin
												out_pix[15 : 8] = in_pix[15 : 8] - 1;
												h = h + 1; 
												
											end
										end
									end
								end
							end
						end
						
						//Cand finalizam parcurgerea blocului trecem intr-o stare de incrementare
						//unde incrementam valorile lui m si n pentru a modifica blocul pe care
						//lucram
						if(i == m + 4 - 1 && j == n + 4 - 1) begin
							state_next = `INCREMENTARE;
						end
							else begin
								j = j + 1;
								if(j == n + 4) begin
									i = i + 1;
									j = n;
								end
							state_next = `CITIRE_CODARE1;	
							end	
					end
					
					//Incrementare similara celei din task ul anterior
					`INCREMENTARE:begin
						if(i == m + 4 - 1 && j == n + 4 - 1) begin
							if(m == 60 && n == 60)begin
								//daca am codificat ultimul bloc, procesul este finalizat
								//drept urmare mergem in starea de finalizare
								state_next = `FINALIZARE_CODARE;
							end
							else begin
								n = n  + 4;
								h = 0;
								if(n == 64) begin
									m = m + 4;
									n = 0;
									h = 0;
								end
								i = m;
								j = n;
								//Dupa ce am finalizat codificarea primului bloc
								//mergem in starea de initiere pentru a codifica
								//urmatoarele 2 caractere
								state_next = `INITIERE1;
							end
						end
					end
					
					//FINALIZARE_CODARE : Marcheaza finalizarea a taskului prin setarea
					//							semnalului encode_done ca fiind activ, dar si a
					//							intregului proces.
					`FINALIZARE_CODARE: begin
						encode_done = 1;			
					end
								
		endcase
	 end
    
endmodule
