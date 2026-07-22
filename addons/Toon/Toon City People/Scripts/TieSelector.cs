using System.Collections.Generic;
using UnityEngine;

namespace TieSelector
{

    public class TieSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_TIES = 5
;
        [Range(0, MAXIMUM_NUMBER_TIES - 1)]
        public int Tie;
        public GameObject[] Ties = new GameObject[MAXIMUM_NUMBER_TIES];


        void OnValidate()
        {
		ValidateObject(Tie, Ties);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
